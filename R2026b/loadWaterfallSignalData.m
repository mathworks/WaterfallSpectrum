function [signal, sampleRate, details] = loadWaterfallSignalData(dataSource)
%LOADWATERFALLSIGNALDATA Normalize signal data from a file or workspace value.
%
%   [SIGNAL, SAMPLERATE, DETAILS] = loadWaterfallSignalData(SOURCE) accepts
%   a numeric matrix or vector, table, timetable, or the path to a MAT,
%   CSV, text, DAT, or spreadsheet file.
%
%   For tabular data, variables named Channel1, Signal, Value, Data, or
%   Amplitude are preferred. Otherwise, the first numeric data
%   variable is used. A variable named Time, Timestamp, Datetime, Date, T,
%   or SampleTime is used to infer the sample rate.
%
%   For numeric matrices, rows represent samples. If the first column is
%   strictly increasing, it is treated as time and the second column is
%   treated as the signal. Otherwise, the first column is the signal.
%
%   Copyright 2026 The MathWorks, Inc.

arguments
    dataSource
end

details = struct( ...
    SourceName="", ...
    SignalName="", ...
    TimeName="", ...
    HasTime=false, ...
    XLabel="Normalized Frequency (cycles/sample)");

if ischar(dataSource) || (isstring(dataSource) && isscalar(dataSource))
    sourcePath = string(dataSource);
    if ~isfile(sourcePath)
        error("WaterfallSpectrum:FileNotFound", ...
            "The selected file does not exist: %s", sourcePath);
    end
    [data, sourceName] = readSignalFile(sourcePath);
    details.SourceName = sourceName;
else
    data = dataSource;
    details.SourceName = "workspace data";
end

[signal, time, signalName, timeName] = normalizeData(data);
signal = double(signal(:));

if isempty(time)
    signal = signal(isfinite(signal));
    sampleRate = 1;
else
    time = convertTimeToSeconds(time);
    validRows = isfinite(time) & isfinite(signal);
    time = time(validRows);
    signal = signal(validRows);

    [time, order] = sort(time);
    signal = signal(order);
    [time, uniqueRows] = unique(time, "stable");
    signal = signal(uniqueRows);

    intervals = diff(time);
    if isempty(intervals) || any(intervals <= 0)
        error("WaterfallSpectrum:InvalidTime", ...
            "Time values must contain at least two distinct samples.");
    end

    sampleInterval = median(intervals, "omitmissing");
    sampleRate = 1 / sampleInterval;
    details.HasTime = true;
    details.XLabel = "Frequency (Hz)";
end

if numel(signal) < 2
    error("WaterfallSpectrum:InsufficientData", ...
        "The selected data must contain at least two finite signal samples.");
end

details.SignalName = signalName;
details.TimeName = timeName;

end

function [data, sourceName] = readSignalFile(sourcePath)
%READSIGNALFILE Read a supported file into a MATLAB value.

[~, fileStem, extension] = fileparts(sourcePath);
sourceName = string(fileStem);

switch lower(extension)
    case ".mat"
        variables = load(sourcePath);
        [data, variableName] = selectLoadedVariable(variables);
        sourceName = sourceName + ":" + variableName;
    case {".csv", ".txt", ".dat", ".tsv", ".xlsx", ".xls"}
        try
            data = readtable(sourcePath, VariableNamingRule="preserve");
        catch tableError
            try
                data = readmatrix(sourcePath);
            catch matrixError
                error("WaterfallSpectrum:ImportFailed", ...
                    "Could not import %s as a table or matrix.%s%s", ...
                    sourcePath, newline, ...
                    tableError.message + newline + matrixError.message);
            end
        end
    otherwise
        error("WaterfallSpectrum:UnsupportedFile", ...
            "Unsupported file type '%s'.", extension);
end

end

function [data, variableName] = selectLoadedVariable(variables)
%SELECTLOADEDVARIABLE Choose the largest supported MAT-file variable.

variableNames = string(fieldnames(variables));
scores = -inf(size(variableNames));

for index = 1:numel(variableNames)
    value = variables.(variableNames(index));
    if istable(value) || istimetable(value)
        scores(index) = height(value) * max(width(value), 1);
    elseif (isnumeric(value) || islogical(value)) && ...
            ismatrix(value) && ~isempty(value)
        scores(index) = numel(value);
    end
end

[~, order] = sort(scores, "descend");
for index = order(:).'
    if ~isfinite(scores(index))
        break
    end
    candidate = variables.(variableNames(index));
    try
        normalizeData(candidate);
        data = candidate;
        variableName = variableNames(index);
        return
    catch
        % Try the next supported variable.
    end
end

error("WaterfallSpectrum:NoSupportedVariable", ...
    "The MAT file does not contain a usable numeric matrix, table, " + ...
    "or timetable.");

end

function [signal, time, signalName, timeName] = normalizeData(data)
%NORMALIZEDATA Extract one signal and optional time values.

if istimetable(data)
    time = data.Properties.RowTimes;
    timeName = string(data.Properties.DimensionNames{1});
    [signal, signalName] = selectTableSignal(data, "");
elseif istable(data)
    [time, timeName] = selectTableTime(data);
    [signal, signalName] = selectTableSignal(data, timeName);
elseif (isnumeric(data) || islogical(data)) && ismatrix(data)
    [signal, time] = normalizeMatrix(data);
    signalName = "matrix column 1";
    timeName = "";
    if ~isempty(time)
        signalName = "matrix column 2";
        timeName = "matrix column 1";
    end
else
    error("WaterfallSpectrum:UnsupportedData", ...
        "Data must be a numeric matrix, table, or timetable.");
end

end

function [time, timeName] = selectTableTime(data)
%SELECTTABLETIME Find a named or clearly time-like table variable.

variableNames = string(data.Properties.VariableNames);
normalizedNames = lower(regexprep(variableNames, "[^a-zA-Z0-9]", ""));
preferredNames = ["time", "timestamp", "datetime", "date", "t", ...
    "sampletime"];
timeIndex = find(ismember(normalizedNames, preferredNames), 1);

if isempty(timeIndex)
    numericIndices = findNumericVariables(data);
    if numel(numericIndices) >= 2
        candidate = firstColumn(data.(variableNames(numericIndices(1))));
        if isTimeLike(candidate)
            timeIndex = numericIndices(1);
        end
    end
end

if isempty(timeIndex)
    time = [];
    timeName = "";
    return
end

timeName = variableNames(timeIndex);
time = firstColumn(data.(timeName));
if isstring(time) || iscellstr(time) || ischar(time) || ...
        iscategorical(time)
    try
        time = datetime(string(time));
    catch
        error("WaterfallSpectrum:InvalidTime", ...
            "The time variable '%s' could not be converted to datetime.", ...
            timeName);
    end
elseif ~(isnumeric(time) || isdatetime(time) || isduration(time))
    error("WaterfallSpectrum:InvalidTime", ...
        "The time variable '%s' must contain numeric or time values.", ...
        timeName);
end

end

function [signal, signalName] = selectTableSignal(data, timeName)
%SELECTTABLESIGNAL Select a preferred or first numeric table variable.

variableNames = string(data.Properties.VariableNames);
numericIndices = findNumericVariables(data);
if strlength(timeName) > 0
    numericIndices(variableNames(numericIndices) == timeName) = [];
end
if isempty(numericIndices)
    error("WaterfallSpectrum:NoNumericSignal", ...
        "The table does not contain a numeric signal variable.");
end

normalizedNames = lower(regexprep(variableNames, "[^a-zA-Z0-9]", ""));
preferredNames = ["channel1", "signal", "value", "data", ...
    "amplitude"];
preferredIndex = find(ismember(normalizedNames(numericIndices), ...
    preferredNames), 1);
if isempty(preferredIndex)
    signalIndex = numericIndices(1);
else
    signalIndex = numericIndices(preferredIndex);
end

signalName = variableNames(signalIndex);
signal = firstColumn(data.(signalName));

end

function indices = findNumericVariables(data)
%FINDNUMERICVARIABLES Return numeric or logical table variable indices.

variableNames = string(data.Properties.VariableNames);
isNumeric = false(size(variableNames));
for index = 1:numel(variableNames)
    value = data.(variableNames(index));
    isNumeric(index) = (isnumeric(value) || islogical(value)) && ...
        ismatrix(value) && size(value, 2) >= 1;
end
indices = find(isNumeric);

end

function value = firstColumn(value)
%FIRSTCOLUMN Return a table variable as a sample column.

value = value(:, 1);

end

function [signal, time] = normalizeMatrix(data)
%NORMALIZEMATRIX Interpret a numeric vector or sample-by-channel matrix.

if isempty(data)
    error("WaterfallSpectrum:EmptyData", "The selected data is empty.");
end
if isvector(data)
    signal = data(:);
    time = [];
    return
end

if size(data, 2) > size(data, 1) && size(data, 1) <= 16
    data = data.';
end

candidateTime = data(:, 1);
if size(data, 2) >= 2 && isTimeLike(candidateTime)
    time = candidateTime;
    signal = data(:, 2);
else
    time = [];
    signal = data(:, 1);
end

end

function tf = isTimeLike(value)
%ISTIMELIKE Determine whether a vector can represent increasing time.

if isdatetime(value) || isduration(value)
    numericValue = seconds(value - value(1));
elseif isnumeric(value) && isreal(value)
    numericValue = double(value);
else
    tf = false;
    return
end

numericValue = numericValue(:);
tf = numel(numericValue) >= 2 && all(isfinite(numericValue)) && ...
    all(diff(numericValue) > 0);

end

function time = convertTimeToSeconds(time)
%CONVERTTIMETOSECONDS Convert supported time values to elapsed seconds.

if isdatetime(time)
    time = seconds(time - time(1));
elseif isduration(time)
    time = seconds(time);
else
    time = double(time);
end
time = time(:);

end
