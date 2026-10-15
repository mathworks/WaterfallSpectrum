classdef uiWaterfallSpectrum < matlab.ui.componentcontainer.ComponentContainer

    % Copyright 2026 The MathWorks, Inc.

    % Properties that correspond to underlying components
    properties (Access = private, Transient, NonCopyable)
        GridLayout  matlab.ui.container.GridLayout
        AxesPanel   matlab.ui.container.Panel
    end

    properties (SetAccess = private, Transient, NonCopyable)
        % RawAxes is the upper line-plot axes.
        RawAxes matlab.graphics.axis.Axes

        % ImageAxes is the lower waterfall-image axes.
        ImageAxes matlab.graphics.axis.Axes
    end
    
    properties (Access = public)
        % RawData is the current trace shown in the upper axes.
        RawData double = double.empty(0, 1)

        % WaterfallData contains one spectrum per column.
        WaterfallData double = double.empty(0, 0)

        % XData contains the coordinate for each frequency bin.
        XData double = double.empty(0, 1)

        % MaximumHistory is the number of latest spectra displayed.
        MaximumHistory (1, 1) double ...
            {mustBeInteger, mustBePositive} = 30

        % Colormap matches the choices in the source app.
        Colormap (1, 1) string = "hot"

        % RawYLimits is [minimum maximum], or [NaN NaN] for automatic.
        RawYLimits (1, 2) double = [0 120]

        % ColorLimits is [minimum maximum], or [NaN NaN] for automatic.
        ColorLimits (1, 2) double = [NaN NaN]

        RawYLabel (1, 1) string = "Magnitude"
        XLabel (1, 1) string = "Frequency (Hz)"
        RawTitle (1, 1) string = ""
        ImageTitle (1, 1) string = ""
        ShowColorbar (1, 1) logical = false
    end

    properties (Access = private, Transient, NonCopyable)
        TiledLayout matlab.graphics.layout.TiledChartLayout
        RawLine matlab.graphics.chart.primitive.Line
        WaterfallImage matlab.graphics.primitive.Image
        ImageColorbar matlab.graphics.illustration.ColorBar
    end

    methods (Access = public)
        function appendSpectrum(comp, spectrum, xData)
            %APPENDSPECTRUM Display and append one spectrum.
            %
            %   appendSpectrum(p, spectrum) uses the current XData, or bin
            %   numbers when XData is empty.
            %
            %   appendSpectrum(p, spectrum, xData) also sets XData.

            arguments
                comp (1, 1) uiWaterfallSpectrum
                spectrum {mustBeNumeric, mustBeReal, mustBeVector}
                xData {mustBeNumeric, mustBeReal} = []
            end

            spectrum = double(spectrum(:));
            if ~isempty(xData)
                validateattributes(xData, {'numeric'}, ...
                    {'real', 'vector', 'finite'}, ...
                    class(comp), 'xData');
            end
            xData = double(xData(:));

            if ~isempty(xData) && numel(xData) ~= numel(spectrum)
                error("uiWaterfallSpectrum:XDataLength", ...
                    "XData and spectrum must have the same number of elements.");
            end

            if isempty(xData)
                xData = comp.XData;
            end

            if ~isempty(xData) && numel(xData) ~= numel(spectrum)
                error("uiWaterfallSpectrum:XDataLength", ...
                    "The existing XData and spectrum must have the same number of elements.");
            end

            history = comp.WaterfallData;
            if isempty(history)
                history = spectrum;
            else
                if size(history, 1) ~= numel(spectrum)
                    error("uiWaterfallSpectrum:SpectrumLength", ...
                        "Spectrum length must match the number of rows in WaterfallData.");
                end
                history(:, end + 1) = spectrum;
            end

            if size(history, 2) > comp.MaximumHistory
                history = history(:, end - comp.MaximumHistory + 1:end);
            end

            if ~isempty(xData)
                comp.XData = xData;
            end
            comp.RawData = spectrum;
            comp.WaterfallData = history;
        end

        function clearData(comp)
            %CLEARDATA Remove the trace and waterfall history.
            comp.RawData = double.empty(0, 1);
            comp.WaterfallData = double.empty(0, 0);
            comp.XData = double.empty(0, 1);
        end
        
    end

    methods
        function set.RawData(comp, value)
            if isempty(value)
                comp.RawData = double.empty(0, 1);
                return
            end

            validateattributes(value, {'numeric'}, ...
                {'real', 'vector'}, class(comp), 'RawData');
            comp.RawData = double(value(:));
        end

        function set.WaterfallData(comp, value)
            if isempty(value)
                comp.WaterfallData = double.empty(0, 0);
                return
            end

            validateattributes(value, {'numeric'}, ...
                {'real', '2d'}, class(comp), 'WaterfallData');
            if isvector(value)
                value = value(:);
            end
            comp.WaterfallData = double(value);
        end

        function set.XData(comp, value)
            if isempty(value)
                comp.XData = double.empty(0, 1);
                return
            end

            validateattributes(value, {'numeric'}, ...
                {'real', 'vector', 'finite'}, class(comp), 'XData');
            comp.XData = double(value(:));
        end

        function set.Colormap(comp, value)
            value = validatestring(value, ...
                {'hot', 'jet', 'gray', 'bone', 'summer'}, ...
                class(comp), 'Colormap');
            comp.Colormap = string(value);
        end

        function set.RawYLimits(comp, value)
            comp.RawYLimits = validateLimits(comp, value, "RawYLimits");
        end

        function set.ColorLimits(comp, value)
            comp.ColorLimits = validateLimits(comp, value, "ColorLimits");
        end
    end

    methods (Access = private)
        function [xData, binCount] = resolveCoordinates(comp)
            rawCount = numel(comp.RawData);

            if isempty(comp.WaterfallData)
                historyCount = 0;
            else
                historyCount = size(comp.WaterfallData, 1);
            end

            populatedCounts = [rawCount historyCount];
            populatedCounts = populatedCounts(populatedCounts > 0);
            if ~isempty(populatedCounts) && ...
                    any(populatedCounts ~= populatedCounts(1))
                error("uiWaterfallSpectrum:DataSizeMismatch", ...
                    "RawData length must match the number of rows in WaterfallData.");
            end

            if isempty(populatedCounts)
                binCount = numel(comp.XData);
            else
                binCount = populatedCounts(1);
            end

            if ~isempty(comp.XData) && numel(comp.XData) ~= binCount
                error("uiWaterfallSpectrum:XDataLength", ...
                    "XData length must match the number of data bins.");
            end

            if isempty(comp.XData)
                xData = (1:binCount).';
            else
                xData = comp.XData;
            end
        end

        function renderRawTrace(comp, xData)
            if isempty(comp.RawData)
                comp.RawLine.XData = NaN;
                comp.RawLine.YData = NaN;
                comp.RawLine.Visible = "off";
                return
            end

            comp.RawLine.XData = xData;
            comp.RawLine.YData = comp.RawData;
            comp.RawLine.Visible = "on";
        end

        function renderWaterfallImage(comp, xData, binCount)
            if isempty(comp.WaterfallData)
                comp.WaterfallImage.CData = NaN;
                comp.WaterfallImage.XData = [0 1];
                comp.WaterfallImage.YData = [0 1];
                comp.WaterfallImage.Visible = "off";
                return
            end

            firstColumn = max(1, ...
                size(comp.WaterfallData, 2) - comp.MaximumHistory + 1);
            displayData = comp.WaterfallData(:, firstColumn:end).';
            frameCount = size(displayData, 1);

            comp.WaterfallImage.CData = displayData;
            comp.WaterfallImage.XData = imageExtent(xData, binCount);
            comp.WaterfallImage.YData = imageExtent(1:frameCount, frameCount);
            comp.WaterfallImage.Visible = "on";
            comp.ImageAxes.YLim = [0.5 frameCount + 0.5];

            function extent = imageExtent(coordinates, count)
                %IMAGEEXTENT Return a nondegenerate two-element image extent.

                if count == 1
                    extent = double(coordinates(1)) + [-0.5 0.5];
                else
                    extent = double([coordinates(1) coordinates(end)]);
                end
            end

        end

        function applyAppearance(comp)
            ylabel(comp.RawAxes, comp.RawYLabel, "Interpreter", "none");
            title(comp.RawAxes, comp.RawTitle, "Interpreter", "none");
            xlabel(comp.RawAxes, "");
            comp.RawAxes.XTickLabel = [];

            xlabel(comp.ImageAxes, comp.XLabel, "Interpreter", "none");
            title(comp.ImageAxes, comp.ImageTitle, "Interpreter", "none");
            comp.ImageAxes.YTickLabel = [];

            colormap(comp.ImageAxes, char(comp.Colormap));
            comp.ImageColorbar.Visible = matlab.lang.OnOffSwitchState( ...
                comp.ShowColorbar);

            applyAxisLimits(comp.RawAxes, "YLim", comp.RawYLimits);
            applyAxisLimits(comp.ImageAxes, "CLim", comp.ColorLimits);
            

            function applyAxisLimits(axesHandle, propertyName, limits)
                %APPLYAXISLIMITS Apply explicit limits or restore automatic limits.

                modeProperty = propertyName + "Mode";
                if all(isnan(limits))
                    axesHandle.(modeProperty) = "auto";
                else
                    axesHandle.(propertyName) = limits;
                end
            end

            [xData, binCount] = resolveCoordinates(comp);
            if binCount > 0
                limits = coordinateLimits(xData);
                comp.RawAxes.XLim = limits;
                comp.ImageAxes.XLim = limits;
                
            end

            function limits = coordinateLimits(xData)
                %COORDINATELIMITS Return increasing limits for shared horizontal axes.

                if isscalar(xData)
                    limits = double(xData(1)) + [-0.5 0.5];
                else
                    limits = double([min(xData) max(xData)]);
                end
            end
        end

        function limits = validateLimits(comp, value, propertyName)
            validateattributes(value, {'numeric'}, ...
                {'real', 'size', [1 2]}, class(comp), char(propertyName));
            value = double(value);

            isAutomatic = all(isnan(value));
            isIncreasing = all(isfinite(value)) && value(1) < value(2);
            if ~(isAutomatic || isIncreasing)
                error("uiWaterfallSpectrum:InvalidLimits", ...
                    "%s must be increasing finite values or [NaN NaN].", ...
                    propertyName);
            end
            limits = value;
        end        
    end




    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function postSetupFcn(comp)
            comp.TiledLayout = tiledlayout(comp.AxesPanel, 2, 1, ...
                "Padding", "none", "TileSpacing", "none");
            comp.RawAxes = nexttile(comp.TiledLayout, 1);
            comp.RawLine = plot(comp.RawAxes, NaN, NaN);
            grid(comp.RawAxes, "on");
            comp.RawAxes.XTickLabel = [];
            comp.RawAxes.XLimitMethod = "tight";

            comp.ImageAxes = nexttile(comp.TiledLayout, 2);
            comp.WaterfallImage = imagesc(comp.ImageAxes, NaN);
            comp.ImageAxes.YDir = "normal";
            comp.ImageAxes.YTickLabel = [];
            comp.ImageAxes.XLimitMethod = "tight";
            comp.ImageColorbar = colorbar(comp.ImageAxes);
            comp.ImageColorbar.Location = "east";
            comp.ImageColorbar.Visible = "off";
        end
    end

    methods (Access = protected)
        
        % Code that executes when the value of a property is changed
        function update(comp)
            [xData, binCount] = resolveCoordinates(comp);

            renderRawTrace(comp, xData);
            renderWaterfallImage(comp, xData, binCount);
            applyAppearance(comp);

            
        end

        % Create the underlying components
        function setup(comp)

            comp.Position = [1 1 320 240];

            % Create GridLayout
            comp.GridLayout = uigridlayout(comp);
            comp.GridLayout.ColumnWidth = {'1x'};
            comp.GridLayout.RowHeight = {'1x'};
            comp.GridLayout.ColumnSpacing = 0;
            comp.GridLayout.RowSpacing = 0;
            comp.GridLayout.Padding = [0 0 0 0];

            % Create AxesPanel
            comp.AxesPanel = uipanel(comp.GridLayout);
            comp.AxesPanel.BorderType = 'none';
            comp.AxesPanel.Layout.Row = 1;
            comp.AxesPanel.Layout.Column = 1;
            
            % Execute the startup function
            postSetupFcn(comp)
        end
    end
end