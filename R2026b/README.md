# Waterfall Spectrum for MATLAB R2026b

This folder contains text versions exported using MATLAB R2026b. The
original `.mlapp` files remain in the parent folder for MATLAB R2026a and
visual component design.

## Setup

Use MATLAB R2026b or newer. Set this folder as MATLAB's Current Folder, then
run:

```matlab
addpath(pwd)
uiWaterfallSpectrum_demo
```

Restart App Designer to refresh its Component Library. The component appears
under **My Components**. See the [main README](../README.md) for streaming,
data formats, examples, and the component API.

The standalone function is also available from this folder:

```matlab
WaterfallSpectrum
```

## Editing and File Layout

- `uiWaterfallSpectrum.m` is a code-only component class. Edit it in the
  MATLAB Editor; use the original `uiWaterfallSpectrum.mlapp` for visual
  component design.
- Keep `uiWaterfallSpectrum_demo.m` and its companion `.xml` file together;
  both files are needed to run the demo. Open the `.m` file in App Designer
  to edit the demo visually.
- Keep `loadWaterfallSignalData.m`, `WaterfallSpectrum.m`, `file_open.png`,
  and `resources/` in this folder.
- The sample [`signal_data.csv`](../signal_data.csv) remains in the parent
  folder. The demo uses that shared file as the initial selection for
  **Load and stream**. You can browse to your own supported data file.

Choose one version per MATLAB session. Restart MATLAB before switching
versions, and avoid `addpath(genpath(...))`. Do not leave the original
repository folder as the Current Folder when using the text versions;
the Current Folder takes precedence over the path.

The exported files and helpers are separate copies. Changes here do not
update the originals; refresh the exports and helpers when maintaining both
versions. The exported demo's sample-file lookup points to the parent folder
to avoid duplicating the shared CSV.

The repository [license](LICENSE.txt) applies to these copies.
