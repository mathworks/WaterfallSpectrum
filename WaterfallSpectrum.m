function [figureHandle, rawAxes, imageAxes] = WaterfallSpectrum( ...
        waterfallData, options)
%WATERFALLSPECTRUM Display a spectrum and its history in a MATLAB(R) figure.
%
%   WaterfallSpectrum() displays a synthetic example.
%
%   WaterfallSpectrum(WATERFALLDATA) displays an N-by-M matrix with one
%   N-bin spectrum per column. The last column is the current spectrum.
%
%   WaterfallSpectrum(WATERFALLDATA, XData=X) uses X for the horizontal
%   coordinates.
%
%   WaterfallSpectrum(___, RawData=Y) displays Y as the current spectrum
%   instead of the last column of WATERFALLDATA.
%
%   [FIG, RAWAXES, IMAGEAXES] = WaterfallSpectrum(___) returns the figure
%   and the two axes.
%
%   Name-value arguments:
%     XData          - Horizontal coordinates (default: bin numbers)
%     RawData        - Current spectrum (default: last history column)
%     MaximumHistory - Number of latest spectra to show (default: 30)
%     Colormap       - hot, jet, gray, bone, or summer (default: hot)
%     RawYLimits     - Upper axes limits or [NaN NaN] (default: [0 120])
%     ColorLimits    - Color limits or [NaN NaN] (default: automatic)
%     RawYLabel      - Upper axes y-axis label (default: "Magnitude")
%     XLabel         - Lower axes x-axis label (default: "Frequency (Hz)")
%     RawTitle       - Upper axes title (default: "Current Spectrum")
%     ImageTitle     - Lower axes title (default: "")
%     ShowColorbar   - Show the waterfall colorbar (default: false)
%
%   Copyright 2026 The MathWorks, Inc.

arguments
    waterfallData {mustBeNumeric, mustBeReal} = double.empty(0, 0)
    options.XData {mustBeNumeric, mustBeReal} = double.empty(0, 1)
    options.RawData {mustBeNumeric, mustBeReal} = double.empty(0, 1)
    options.MaximumHistory (1, 1) double ...
        {mustBeInteger, mustBePositive} = 30
    options.Colormap (1, 1) string ...
        {mustBeMember(options.Colormap, ...
        ["hot", "jet", "gray", "bone", "summer"])} = "hot"
    options.RawYLimits (1, 2) double = [NaN NaN]%[0 120]
    options.ColorLimits (1, 2) double = [NaN NaN]
    options.RawYLabel (1, 1) string = "Magnitude"
    options.XLabel (1, 1) string = "Frequency (Hz)"
    options.RawTitle (1, 1) string = "Current Spectrum"
    options.ImageTitle (1, 1) string = ""
    options.ShowColorbar (1, 1) logical = false
end

if nargin == 0
    [waterfallData, options.XData] = createExampleData();
end

validateattributes(waterfallData, {'numeric'}, {'real', '2d'}, ...
    mfilename, 'waterfallData');
if isvector(waterfallData) && ~isempty(waterfallData)
    waterfallData = waterfallData(:);
end
waterfallData = double(waterfallData);

xData = options.XData(:);
validateattributes(xData, {'numeric'}, {'real', 'vector', 'finite'}, ...
    mfilename, 'XData');
xData = double(xData);

rawData = options.RawData(:);
validateattributes(rawData, {'numeric'}, {'real', 'vector'}, ...
    mfilename, 'RawData');
rawData = double(rawData);

if isempty(rawData) && ~isempty(waterfallData)
    rawData = waterfallData(:, end);
end

binCounts = [size(waterfallData, 1), numel(rawData), numel(xData)];
binCounts = binCounts(binCounts > 0);
if ~isempty(binCounts) && any(binCounts ~= binCounts(1))
    error("WaterfallSpectrum:DataSizeMismatch", ...
        "XData, RawData, and each WaterfallData column must have " + ...
        "the same number of elements.");
end

if isempty(binCounts)
    binCount = 0;
else
    binCount = binCounts(1);
end
if isempty(xData)
    xData = (1:binCount).';
end

validateLimits(options.RawYLimits, "RawYLimits");
validateLimits(options.ColorLimits, "ColorLimits");

if size(waterfallData, 2) > options.MaximumHistory
    waterfallData = waterfallData(:, ...
        end - options.MaximumHistory + 1:end);
end

figureHandle = figure( ...
    Name="Waterfall Spectrum", ...
    NumberTitle="off", ...
    Color="white");
layout = tiledlayout(figureHandle, 2, 1, ...
    Padding="none", ...
    TileSpacing="none");

rawAxes = nexttile(layout, 1);
if isempty(rawData)
    plot(rawAxes, NaN, NaN);
else
    plot(rawAxes, xData, rawData);
end
grid(rawAxes, "on");
ylabel(rawAxes, options.RawYLabel, Interpreter="none");
title(rawAxes, options.RawTitle, Interpreter="none");
rawAxes.XTickLabel = [];

imageAxes = nexttile(layout, 2);
if isempty(waterfallData)
    waterfallImage = imagesc(imageAxes, [0 1], [0 1], NaN);
    waterfallImage.Visible = "off";
else
    frameCount = size(waterfallData, 2);
    imagesc(imageAxes, imageExtent(xData, binCount), ...
        imageExtent(1:frameCount, frameCount), waterfallData.');
    imageAxes.YLim = [0.5 frameCount + 0.5];
end
imageAxes.YDir = "normal";
imageAxes.YTickLabel = [];
xlabel(imageAxes, options.XLabel, Interpreter="none");
title(imageAxes, options.ImageTitle, Interpreter="none");
colormap(imageAxes, char(options.Colormap));

colorbarHandle = colorbar(imageAxes);
colorbarHandle.Location = "east";
colorbarHandle.Visible = matlab.lang.OnOffSwitchState( ...
    options.ShowColorbar);

applyLimits(rawAxes, "YLim", options.RawYLimits);
applyLimits(imageAxes, "CLim", options.ColorLimits);

if binCount > 0
    if binCount == 1
        xLimits = xData(1) + [-0.5 0.5];
    else
        xLimits = [min(xData) max(xData)];
    end
    rawAxes.XLim = xLimits;
    imageAxes.XLim = xLimits;
end

linkaxes([rawAxes imageAxes], "x");

end

function [history, frequency] = createExampleData()
%CREATEEXAMPLEDATA Create a synthetic moving spectral peak.

nBins = 128;
nFrames = 30;
frequency = linspace(0, 200e3, nBins).';
frame = 1:nFrames;
center = 80e3 + 35e3*sin(2*pi*frame/nFrames);
history = 10 + 100*exp(-((frequency-center)/15e3).^2);
history = history + 5*rand(nBins, nFrames);

end

function extent = imageExtent(coordinates, count)
%IMAGEEXTENT Return a nondegenerate two-element image extent.

if count == 1
    extent = double(coordinates(1)) + [-0.5 0.5];
else
    extent = double([coordinates(1) coordinates(end)]);
end

end

function applyLimits(axesHandle, propertyName, limits)
%APPLYLIMITS Apply explicit limits or restore automatic limits.

if all(isnan(limits))
    axesHandle.(propertyName + "Mode") = "auto";
else
    axesHandle.(propertyName) = limits;
end

end

function validateLimits(value, propertyName)
%VALIDATELIMITS Validate explicit or automatic two-element limits.

isAutomatic = all(isnan(value));
isIncreasing = all(isfinite(value)) && value(1) < value(2);
if ~(isAutomatic || isIncreasing)
    error("WaterfallSpectrum:InvalidLimits", ...
        "%s must be increasing finite values or [NaN NaN].", ...
        propertyName);
end

end
