"""
convert_to_coreml.py

Converts the traced PyTorch model from train_model.py into a Core ML
.mlpackage you can drop straight into Xcode.

Usage:
    python3 convert_to_coreml.py --model quality_model_traced.pt --output LensCheckQuality.mlpackage

Requires: coremltools, torch
    pip install coremltools torch

Note: coremltools versions occasionally rename small API details
(e.g. ct.ImageType's color_layout argument). If you hit a
TypeError/AttributeError on the ct.convert(...) call below, run
`pip show coremltools` and check the version's docs — the fix is
usually a one-argument rename, not a structural change.
"""

import argparse
from pathlib import Path

import coremltools as ct
import torch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True, help="Traced .pt model from train_model.py")
    parser.add_argument("--output", type=Path, default=Path("LensCheckQuality.mlpackage"))
    args = parser.parse_args()

    traced_model = torch.jit.load(str(args.model))
    traced_model.eval()

    example_input = torch.rand(1, 3, 224, 224)

    # scale=1/255, bias=0 maps Core ML's native 0-255 image input down to the
    # [0,1] range the traced model expects (see QualityModel.forward in
    # train_model.py, which normalizes internally from there).
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.ImageType(
                name="image",
                shape=example_input.shape,
                scale=1 / 255.0,
                bias=[0, 0, 0],
            )
        ],
        outputs=[ct.TensorType(name="scores")],
        minimum_deployment_target=ct.target.iOS17,
    )

    mlmodel.author = "Mohammad Zaid"
    mlmodel.short_description = "Predicts [sharpness, exposure] quality scores (0-100) for a photo."
    mlmodel.input_description["image"] = "A photo to assess, any size (resized internally to 224x224)."
    mlmodel.output_description["scores"] = "Two values: [sharpness_score, exposure_score], each 0-100."

    mlmodel.save(str(args.output))
    print(f"Saved {args.output}")
    print("Next step: drag this .mlpackage into your Xcode project, then build once (Cmd+B)")
    print("so Xcode generates the Swift class before you reference it in code.")


if __name__ == "__main__":
    main()
