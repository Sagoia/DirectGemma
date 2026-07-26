# gemma.cpp

gemma.cpp is a lightweight, standalone C++ inference engine for the Gemma
foundation models from Google.

For additional information about Gemma, see
[ai.google.dev/gemma](https://ai.google.dev/gemma). Model weights, including
gemma.cpp specific artifacts, are
[available on kaggle](https://www.kaggle.com/models/google/gemma-2).

## Who is this project for?

Modern LLM inference engines are sophisticated systems, often with bespoke
capabilities extending beyond traditional neural network runtimes. With this
comes opportunities for research and innovation through co-design of high level
algorithms and low-level computation. However, there is a gap between
deployment-oriented C++ inference runtimes, which are not designed for
experimentation, and Python-centric ML research frameworks, which abstract away
low-level computation through compilation.

gemma.cpp provides a minimalist implementation of Gemma-2, Gemma-3, and
PaliGemma-2 models, focusing on simplicity and directness rather than full
generality. This is inspired by vertically-integrated model implementations such
as [ggml](https://github.com/ggerganov/ggml),
[llama.c](https://github.com/karpathy/llama2.c), and
[llama.rs](https://github.com/srush/llama2.rs).

gemma.cpp targets experimentation and research use cases. It is intended to be
straightforward to embed in other projects with minimal dependencies and also
easily modifiable with a small ~2K LoC core implementation (along with ~4K LoC
of supporting utilities). We use the [Google
Highway](https://github.com/google/highway) Library to take advantage of
portable SIMD for CPU inference.

For production-oriented edge deployments we recommend standard deployment
pathways using Python frameworks like JAX, Keras, PyTorch, and Transformers
([all model variations here](https://www.kaggle.com/models/google/gemma)).

## Contributing

Community contributions large and small are welcome. See
[DEVELOPERS.md](https://github.com/google/gemma.cpp/blob/main/DEVELOPERS.md)
for additional notes contributing developers and [join the discord by following
this invite link](https://discord.gg/H5jCBAWxAe). This project follows
[Google's Open Source Community
Guidelines](https://opensource.google.com/conduct/).

> [!NOTE] Active development is currently done on the `dev` branch. Please open
> pull requests targeting `dev` branch instead of `main`, which is intended to
> be more stable.

## What's inside?

-   LLM

    -   CPU-only inference for: Gemma 2-3, PaliGemma 2.
    -   Sampling with TopK and temperature.
    -   Backward pass (VJP) and Adam optimizer for Gemma research.

-   Optimizations

    -   Mixed-precision (fp8, bf16, fp32, fp64 bit) GEMM:
        -   Designed for BF16 instructions, can efficiently emulate them.
        -   Automatic runtime autotuning 7 parameters per matrix shape.
    -   Weight compression integrated directly into GEMM:
        -   Custom fp8 format with 2..3 mantissa bits; tensor scaling.
        -   Also bf16, f32 and non-uniform 4-bit (NUQ); easy to add new formats.

-   Infrastructure

    -   SIMD: single implementation via Highway. Chooses ISA at runtime.
    -   Tensor parallelism: CCX-aware, multi-socket thread pool.
    -   Disk I/O: memory map or parallel read (heuristic with user override).
    -   Custom format with forward/backward-compatible metadata serialization.
    -   Model conversion from Safetensors, not yet open sourced.
    -   Native MSVC projects for Windows.

-   Frontends

    -   C++ APIs with streaming for single query and batched inference.
    -   Basic interactive command-line app.

## Quick Start

### System requirements

Before starting, install Visual Studio with the **Desktop development with
C++** workload. The native build uses MSVC and the vcpkg bundled with Visual
Studio. To build for ARM64 locally, also install the MSVC ARM64 build tools.
You need `tar` to extract model archives from Kaggle.

```sh
winget install --id Microsoft.VisualStudio.BuildTools --force --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools;installRecommended"
```

### Step 1: Obtain model weights and tokenizer from Kaggle or Hugging Face Hub

Visit the
[Kaggle page for Gemma-2](https://www.kaggle.com/models/google/gemma-2/gemmaCpp)
and select `Model Variations |> Gemma C++`.

On this tab, the `Variation` dropdown includes the options below. Note bfloat16
weights are higher fidelity, while 8-bit switched floating point weights enable
faster inference. In general, we recommend starting with the `-sfp` checkpoints.

> [!NOTE] **Important**: We strongly recommend starting off with the
> `gemma2-2b-it-sfp` model to get up and running.

Gemma 2 models are named `gemma2-2b-it` for 2B and `9b-it` or `27b-it`. See the
`ModelPrefix` function in `configs.cc`.

### Step 2: Extract Files

After filling out the consent form, the download should proceed to retrieve a
tar archive file `archive.tar.gz`. Extract files from `archive.tar.gz` (this can
take a few minutes):

```
tar -xf archive.tar.gz
```

This should produce a file containing model weights such as `2b-it-sfp.sbs` and
a tokenizer file (`tokenizer.spm`). You may want to move these files to a
convenient directory location (e.g. the `build/` directory in this repo).

### Step 3: Build with Visual Studio

Restore the vcpkg manifest once from the repository root, explicitly selecting
the target architecture:

```powershell
.\msvc\gemma\restore-vcpkg.ps1 -Architecture x64
```

The script uses the vcpkg bundled with Visual Studio and installs the manifest
packages into `msvc\gemma\vcpkg_installed`. It is also the dependency restore
step used by CI. `-Architecture` is required and accepts only `x64` or `ARM64`;
there is no implicit default.

Then open `msvc\gemma\gemma.slnx`, select `x64` or `ARM64` and the desired
configuration, and build the solution. Restore dependencies once per target
platform:

```powershell
.\msvc\gemma\restore-vcpkg.ps1 -Architecture x64
.\msvc\gemma\restore-vcpkg.ps1 -Architecture ARM64
```

From a Visual Studio Developer PowerShell, the equivalent command is:

```powershell
.\msvc\gemma\restore-vcpkg.ps1 -Architecture x64
msbuild msvc\gemma\gemma.slnx /t:Build /p:Configuration=Release /p:Platform=x64 /m
```

For a native ARM64 build, run these commands from an ARM64 Visual Studio
Developer PowerShell:

```powershell
.\msvc\gemma\restore-vcpkg.ps1 -Architecture ARM64
msbuild msvc\gemma\gemma.slnx /t:Build /graph /m `
  /p:Configuration=Release /p:Platform=ARM64 `
  /p:PreferredToolArchitecture=ARM64 `
  /p:UseMSBuildCache=false
```

The binaries and libraries are written to
`msvc\gemma\build\<Platform>\Release`. Intermediate files remain under
`msvc\gemma\build\obj` and are also separated by platform.

### CI build cache

GitHub Actions builds x64 on `windows-latest` and ARM64 natively on
`windows-11-vs2026-arm`. Both architectures use separate vcpkg binary caches.
The x64 job also uses `Microsoft.MSBuildCache.Local`; ARM64 does not because
MSBuild's file-access reporting is currently limited to x64 MSBuild. Normal
Visual Studio and command-line builds do not enable MSBuildCache.

The MSBuildCache preview version is pinned in
`msvc\gemma\packages.config`. Dependabot checks that NuGet package and the
workflow actions weekly and opens update pull requests when newer versions are
available; upgrades are reviewed rather than applied silently.

### Step 4: Run

You can now run `gemma.exe` from
`msvc\gemma\build\x64\<Configuration>`.

`gemma` has the following required arguments:

Argument      | Description                  | Example value
------------- | ---------------------------- | ---------------
`--weights`   | The compressed weights file. | `2b-it-sfp.sbs`
`--tokenizer` | The tokenizer file.          | `tokenizer.spm`

Example invocation for the following configuration:

-   weights file `gemma2-2b-it-sfp.sbs` (Gemma2 2B instruction-tuned model,
    8-bit switched floating point).
-   Tokenizer file `tokenizer.spm` (can omit for single-format weights files
    created after 2025-05-06, or output by migrate_weights.cc).

```sh
./gemma \
--tokenizer tokenizer.spm --weights gemma2-2b-it-sfp.sbs
```

### PaliGemma Vision-Language Model

This repository includes a version of the PaliGemma 2 VLM
([paper](https://arxiv.org/abs/2412.03555)). We provide a C++ implementation of
the PaliGemma 2 model here.

To use the version of PaliGemma included in this repository, build the gemma
binary as noted above in Step 3. Download the compressed weights and tokenizer
from
[Kaggle](https://www.kaggle.com/models/google/paligemma-2/gemmaCpp/paligemma2-3b-mix-224)
and run the binary as follows:

```sh
./gemma \
--tokenizer paligemma_tokenizer.model \
--weights paligemma2-3b-mix-224-sfp.sbs \
--image_file paligemma/testdata/image.ppm
```

Note that the image reading code is very basic to avoid depending on an image
processing library for now. We currently only support reading binary PPMs (P6).
So use a tool like `convert` to first convert your images into that format, e.g.

`convert image.jpeg -resize 224x224^ image.ppm`

(As the image will be resized for processing anyway, we can already resize at
this stage for slightly faster loading.)

The interaction with the image (using the mix-224 checkpoint) may then look
something like this:

```
> Describe the image briefly
A large building with two towers in the middle of a city.
> What type of building is it?
church
> What color is the church?
gray
> caption image
A large building with two towers stands tall on the water's edge. The building
has a brown roof and a window on the side. A tree stands in front of the
building, and a flag waves proudly from its top. The water is calm and blue,
reflecting the sky above. A bridge crosses the water, and a red and white boat
rests on its surface. The building has a window on the side, and a flag on top.
A tall tree stands in front of the building, and a window on the building is
visible from the water. The water is green, and the sky is blue.
```

### Migrating to single-file format

There is now a new format for the weights file, which is a single file that
allows to contain the tokenizer (and the model type) directly. A tool to migrate
from the multi-file format to the single-file format is available.

```sh
io/migrate_weights \
  --tokenizer .../tokenizer.spm --weights .../gemma2-2b-it-sfp.sbs \
  --output_weights .../gemma2-2b-it-sfp-single.sbs
```

After migration, you can omit the tokenizer argument like this:

```sh
./gemma --weights .../gemma2-2b-it-sfp-single.sbs
```

### Troubleshooting and FAQs

**Problems building in Windows / Visual Studio**

Open `msvc\gemma\gemma.slnx` in Visual Studio and confirm the selected platform
is `x64` or `ARM64`. Run `.\msvc\gemma\restore-vcpkg.ps1 -Architecture
<platform>` before the first build or after changing `msvc\gemma\vcpkg.json`.
This prevents missing package headers such as `sentencepiece_processor.h` on
clean machines and CI runners. Build outputs are under
`msvc\gemma\build\<platform>\<Configuration>`.

**Model does not respond to instructions and produces strange output**

A common issue is that you are using a pre-trained model, which is not
instruction-tuned and thus does not respond to instructions. Make sure you are
using an instruction-tuned model (`gemma2-2b-it-sfp`) and not a pre-trained
model (any model with a `-pt` suffix).

**What sequence lengths are supported?**

See `max_seq_len` in `configs.cc` and `InferenceArgs.seq_len`. For the Gemma 3
models larger than 1B, this is typically 32K but 128K would also work given
enough RAM. Note that long sequences will be slow due to the quadratic cost of
attention.

**What are some easy ways to make the model run faster?**

1.  Make sure you are using the 8-bit switched floating point `-sfp` models.
    These are half the size of bf16 and thus use less memory bandwidth and cache
    space.
2.  Due to auto-tuning, the second and especially third query will be faster.
3.  If you're on a laptop, make sure power mode is set to maximize performance
    and saving mode is **off**. For most laptops, the power saving modes get
    activated automatically if the computer is not plugged in.
4.  Close other unused cpu-intensive applications.
5.  On macs, anecdotally we observe a "warm-up" ramp-up in speed as performance
    cores get engaged.

We're also working on algorithmic and optimization approaches for faster
inference, stay tuned.

## Usage

`gemma` has different usage modes, controlled by the verbosity flag.

All usage modes are currently interactive, triggering text generation upon
newline input.

| Verbosity       | Usage mode | Details                                       |
| --------------- | ---------- | --------------------------------------------- |
| `--verbosity 0` | Minimal | Only prints generation output. Suitable as a CLI tool. |
| `--verbosity 1` | Default | Standard user-facing terminal UI. |
| `--verbosity 2` | Detailed | Shows additional developer and debug info. |

### Interactive Terminal App

By default, verbosity is set to 1, bringing up a terminal-based interactive
interface when `gemma` is invoked:

```sh
$ ./gemma [...]
  __ _  ___ _ __ ___  _ __ ___   __ _   ___ _ __  _ __
 / _` |/ _ \ '_ ` _ \| '_ ` _ \ / _` | / __| '_ \| '_ \
| (_| |  __/ | | | | | | | | | | (_| || (__| |_) | |_) |
 \__, |\___|_| |_| |_|_| |_| |_|\__,_(_)___| .__/| .__/
  __/ |                                    | |   | |
 |___/                                     |_|   |_|

...

*Usage*
  Enter an instruction and press enter (%C reset conversation, %Q quits).

*Examples*
  - Write an email to grandma thanking her for the cookies.
  - What are some historical attractions to visit around Massachusetts?
  - Compute the nth fibonacci number in javascript.
  - Write a standup comedy bit about WebGPU programming.

> What are some outdoorsy places to visit around Boston?

[ Reading prompt ] .....................


**Boston Harbor and Islands:**

* **Boston Harbor Islands National and State Park:** Explore pristine beaches, wildlife, and maritime history.
* **Charles River Esplanade:** Enjoy scenic views of the harbor and city skyline.
* **Boston Harbor Cruise Company:** Take a relaxing harbor cruise and admire the city from a different perspective.
* **Seaport Village:** Visit a charming waterfront area with shops, restaurants, and a seaport museum.

**Forest and Nature:**

* **Forest Park:** Hike through a scenic forest with diverse wildlife.
* **Quabbin Reservoir:** Enjoy boating, fishing, and hiking in a scenic setting.
* **Mount Forest:** Explore a mountain with breathtaking views of the city and surrounding landscape.

...
```

### Usage as a Command Line Tool

For using the `gemma` executable as a command line tool, it may be useful to
create an alias for gemma.cpp with arguments fully specified:

```sh
alias gemma2b="~/gemma.cpp/build/gemma -- --tokenizer ~/gemma.cpp/build/tokenizer.spm --weights ~/gemma.cpp/build/gemma2-2b-it-sfp.sbs --verbosity 0"
```

Replace the above paths with your own paths to the model and tokenizer paths
from the download.

Here is an example of prompting `gemma` with a truncated input
file (using a `gemma2b` alias like defined above):

```sh
cat configs.h | tail -n 35 | tr '\n' ' ' | xargs -0 echo "What does this C++ code do: " | gemma2b
```

> [!NOTE]
> CLI usage of gemma.cpp is experimental and should take context length
> limitations into account.

The output of the above command should look like:

```sh
[ Reading prompt ] [...]
This C++ code snippet defines a set of **constants** used in a large language model (LLM) implementation, likely related to the **attention mechanism**.

Let's break down the code:
[...]
```

### Incorporating gemma.cpp as a Library in your Project

Add your executable project to `msvc\gemma\gemma.slnx` and reference the
`libgemma`, `hwy`, and `hwy_contrib` projects. Use `$(RepoRoot)` and
`$(HighwayRoot)` for include paths. Package headers and libraries are restored
from `msvc\gemma\vcpkg.json` by the native vcpkg MSBuild integration. The
`hello_world` and `simplified_gemma` projects are working examples.

### Building gemma.cpp as a Library

Build the `libgemma` project directly in Visual Studio, or run:

```powershell
msbuild msvc\gemma\libgemma\libgemma.vcxproj /t:Build /p:Configuration=Release /p:Platform=x64
```

The resulting static library is
`msvc\gemma\build\x64\Release\libgemma.lib`.

## Independent Projects Using gemma.cpp

Some independent projects using gemma.cpp:

- [gemma-cpp-python - Python bindings](https://github.com/namtranase/gemma-cpp-python)
- [lua-cgemma - Lua bindings](https://github.com/ufownl/lua-cgemma)
- [Godot engine demo project](https://github.com/Rliop913/Gemma-godot-demo-project)

If you would like to have your project included, feel free to get in touch or
submit a PR with a `README.md` edit.

## Acknowledgements and Contacts

gemma.cpp was started in fall 2023 by
[Austin Huang](mailto:austinvhuang@google.com) and
[Jan Wassenberg](mailto:janwas@google.com), and subsequently released February
2024 thanks to contributions from Phil Culliton, Paul Chang, and Dan Zheng.

Griffin support was implemented in April 2024 thanks to contributions by Andrey
Mikhaylov, Eugene Kliuchnikov, Jan Wassenberg, Jyrki Alakuijala, Lode
Vandevenne, Luca Versari, Martin Bruse, Phil Culliton, Sami Boukortt, Thomas
Fischbacher and Zoltan Szabadka. It was removed in 2025-09.

Gemma-2 support was implemented in June/July 2024 with the help of several
people.

PaliGemma support was implemented in September 2024 with contributions from
Daniel Keysers.

[Jan Wassenberg](mailto:janwas@google.com) has continued to contribute many
improvements, including major gains in efficiency, since the initial release.

This is not an officially supported Google product.
