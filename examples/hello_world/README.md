# Hello World Example

This is a minimal/template project for using `gemma.cpp` as a library. Instead
of an interactive interface, it sets up the model state and generates text for a
single hard coded prompt.

Build the `hello_world` project from `msvc\gemma\gemma.slnx`. The executable is
written to `msvc\gemma\build\x64\<Configuration>`. Run it with the tokenizer,
compressed weights file, and model type, for example:

```powershell
msvc\gemma\build\x64\Release\hello_world.exe --tokenizer tokenizer.spm --weights 2b-it-sfp.sbs --model 2b-it
```

Should print a greeting to the terminal:

```
"Hello, world! It's a pleasure to greet you all. May your day be filled with joy, peace, and all the things that make your heart soar.
```

For a demonstration of constrained decoding, add the `--reject` flag followed by
a list of token IDs (note that it must be the last flag, since it consumes every
subsequent argument). For example, to reject variations of the word "greeting",
run:

```powershell
msvc\gemma\build\x64\Release\hello_world.exe [...] --reject 32338 42360 78107 106837 132832 143859 154230 190205
```
