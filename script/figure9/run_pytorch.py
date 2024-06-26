import argparse
import datasets
import numpy as np
import torch
import time
from nvitop import Device
import sys
from transformers import AutoModelForCausalLM, AutoTokenizer, AutoConfig

from transformers.models.opt.modeling_opt import OPTModel

def get_gpu_info():
    devices = Device.all()  # or `Device.cuda.all()` to use CUDA ordinal instead
    memory_used = sum([device.memory_used() for device in devices])
    return memory_used / 1024 ** 3

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", type=str, help="Name path", required=True)
    parser.add_argument("--local_model_path", type=str, help="Name path", default=None)
    parser.add_argument("--dtype", type=str, help="float16 or int8", choices=["int8", "float16"], default="float32")
    parser.add_argument("--device_map", type=str, default="balanced", help="float16 or int8")

    return parser.parse_args()

def main():
    args = get_args()
    model_name = args.name
    local_model_path = args.local_model_path

    config = AutoConfig.from_pretrained(model_name)
    config.torch_dtype = torch.float32
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    tokenizer.padding_side = "left"
    tokenizer.pad_token_id = (
        config.pad_token_id if config.pad_token_id else tokenizer.eos_token_id
    )

    model = OPTModel.from_pretrained(
        model_name if not local_model_path else local_model_path,
        device_map=args.device_map,
        torch_dtype=torch.float32,
        pad_token_id=tokenizer.pad_token_id,
    )
    model.eval()

    d = datasets.load_dataset("tatsu-lab/alpaca")["train"]
    N = len(d)
    bsz = 32
    test_time = 20
    seed = 171
    max_seq_length = 128
    device = "cuda"

    np.random.seed(seed)
    datas = []
    for _ in range(100):
        idx = np.random.randint(0, N - bsz)
        inputs = [d[ii + idx]["instruction"] + ' ' + d[ii + idx]["input"] + ' ' + d[ii + idx]["output"] for ii in range(bsz)]

        inputs = tokenizer(inputs, padding="max_length", max_length=max_seq_length, truncation=True)
        inputs = {ii: torch.tensor(jj).to(device) for ii, jj in inputs.items()}
        lens = inputs["attention_mask"].sum(-1).int()
        datas.append([inputs, lens])

    N = len(datas)
    random_idx = np.random.choice(range(N), test_time)
    torch.cuda.empty_cache()
    torch.cuda.synchronize()
    st = time.time()
    for ii, idx in enumerate(random_idx):
        with torch.no_grad():
            model(**datas[idx][0])
        if ii == test_time // 2:
            memory = get_gpu_info()
            print("Memory", memory)
    torch.cuda.synchronize()
    end = time.time()
    print("Forward Implementation", end - st)
    with open("results.txt", "a") as f:
        f.write(f"{model_name},PyTorch,{end - st},{memory}\n")

if __name__ == "__main__":
    main()