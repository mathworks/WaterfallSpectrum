classdef uiWaterfallSpectrum_demo < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './uiWaterfallSpectrum_demo.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        uiWaterfallSpectrum             uiWaterfallSpectrum
        LoadandstreamButton             matlab.ui.control.Button
        plotButton                      matlab.ui.control.Button
    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            movegui(app.UIFigure,"center")
        end

        % Button pushed function: plotButton
        function plotButtonPushed(app, event)
            % Replace this with the component's name in the Component Browser.
            wf = app.uiWaterfallSpectrum;

            nBins = 128;
            nFrames = 30;

            frequency = linspace(0, 200e3, nBins).';
            frame = 1:nFrames;
            center = 80e3 + 35e3*sin(2*pi*frame/nFrames);

            history = 10 + 100*exp(-((frequency-center)/15e3).^2);
            history = history + 5*rand(nBins, nFrames);

            wf.clearData();
            wf.XData = frequency;
            wf.WaterfallData = history;
            wf.RawData = history(:, end);
            wf.RawTitle = "Current Spectrum";
        end

        % Button pushed function: LoadandstreamButton
        function LoadandstreamButtonPushed(app, event)
            wf = app.uiWaterfallSpectrum;

            appFolder = fileparts(which(class(app)));
            defaultFile = fullfile(appFolder, 'signal_data.csv');
            if ~isfile(defaultFile)
                defaultFile = fullfile(appFolder, '..', 'signal_data.csv');
            end
            fileFilters = { ...
                '*.csv;*.txt;*.dat;*.tsv;*.xlsx;*.xls', ...
                'Tabular data files'; ...
                '*.mat', 'MAT-files (*.mat)'; ...
                '*.*', 'All files'};
            [file, folder] = uigetfile(fileFilters, ...
                'Select signal data', defaultFile);

            focus(app.UIFigure)

            if isequal(file, 0)
                return
            end

            try
                [signal, sampleRate, details] = ...
                    loadWaterfallSignalData(fullfile(folder, file));
            catch exception
                uialert(app.UIFigure, exception.message, ...
                    'Unable to Load Signal');
                return
            end

            fftLength = min(256, 2^floor(log2(numel(signal))));
            spectrumInterval = 1e-3;
            if details.HasTime
                hopLength = max(1, round(spectrumInterval * sampleRate));
            else
                hopLength = fftLength;
            end

            startIndices = 1:hopLength:(numel(signal) - fftLength + 1);
            frequency = (0:(fftLength/2 - 1)).' * ...
                (sampleRate / fftLength);

            wf.clearData();
            wf.XData = frequency;
            wf.MaximumHistory = 30;
            wf.RawYLimits = [NaN NaN];
            wf.ColorLimits = [NaN NaN];
            wf.Colormap = "hot";
            wf.XLabel = details.XLabel;
            wf.RawTitle = "Current Spectrum: " + details.SignalName;

            for startIndex = startIndices
                segment = signal(startIndex:startIndex + fftLength - 1);
                spectrum = abs(fft(segment, fftLength));
                spectrum = spectrum(1:fftLength/2);

                wf.appendSpectrum(spectrum);
                drawnow limitrate
                pause(spectrumInterval)
            end
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = uiWaterfallSpectrum_demo(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end
