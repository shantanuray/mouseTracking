function data = batchAnalyzeSalk(filename, pathname)
%% Run analysis and save mouse grab data as a list that can saved to an excel sheet
% data = batchAnalyze(filename, pathname);

if nargin<2
    disp('Select the .mat or raw .h5 files to be analyzed. You can select multiple files.');
    [filename, pathname] = uigetfile( ...
           {'*.mat'; '*.h5'}, ...
            'Pick .mat or .h5 file to analyze', ...
            'MultiSelect', 'on');
end 
if iscell(filename)
    filecount = length(filename);
    markingFile = filename;
elseif ischar(filename)
    filecount = 1;
    markingFile{1} = filename;
else
    error('File not found')
end

refTargetName = 'pellet';
refBodyPartName = 'hand';
modeFlag = 'background-video';
writeFrameCount = true;
videoAngle = '';
% roiSalk = [0, 277; 640, 624];
roiSalk = [0, 0; 800, 600];
actualVidSize = [600 800 3];

for i = 1:filecount
    r = [];
    theta = [];
    diffXY = [];
    outcome = {};
    traceVideoFile = {};
    refXYPosition = [];
    roiXYPosition = [];
    disp(['Processing file # ', num2str(i), ': ', markingFile{i}])
    [ignoreA, markingFileName, markingExt] = fileparts(markingFile{i});
    if strcmpi(markingExt, '.h5')
        if isempty(videoAngle)
            reply = input(['\nAre all the videos taken from the left or right??\n\n',...
                        '[Enter/l/L]    => Left\n',...
                        '[r/R]          => Right    '],'s');
            switch lower(reply)
                case 'l'
                    videoAngle = 'left';
                case 'r'
                    videoAngle = 'right';
                otherwise
                    videoAngle = 'left';
            end
        end
        videoPrefix =  markingFileName(1:strfind(markingFileName, 'DeepCut')-1);
        videoFile = fullfile(pathname, [videoPrefix, '.m4v']);
        [roiData, reachingEvents, isTremorCase, refPixelLength] = ...
              annotateMouseAction(videoFile, fullfile(pathname, markingFile{i}),...
                      'BodyParts', {'hand', 'Finger1', 'Finger2', 'pellet'},...
                      'VideoAngle', videoAngle,...
                      'MarkingROILocation', roiSalk,...
                      'Mode', 'Auto');
    else
       load(fullfile(pathname, markingFileName), 'videoFile', 'roiData', 'reachingEvents', 'refPixelLength'); 
    end
    if i == 1
        data = [{'videoFile',...
            'Frame Count',...
            'Relative Distance',...
            'Relative Angle of Approach',...
            'Relative X Distance',...
            'Relative Y Distance',...
            'Action',...
            'ActionType',...
            'Consequence'},...
            reshape([strcat(roiData.roi, {' - Absolute X'}); strcat(roiData.roi, {' - Absolute Y'}); strcat(roiData.roi, {' - Likelihood'})], 1, 12)];
    end
    [r, theta, diffXY, refXYPosition, roiXYPosition, roiFrames] = analyzeMouseAnnotation(roiData, reachingEvents, videoFile,...
        'RefTargetName', refTargetName, 'RefBodyPartName', refBodyPartName,... 
        'ModeFlag', modeFlag,... 
        'VideoMux', [false false false true], 'WriteFrameCount', writeFrameCount,...
        'ActualVidSize', actualVidSize);
    
    [pathName, trialName, vidExt] = fileparts(videoFile);
    % For windows
    seploc=findstr(trialName,'\');
    if ~isempty(seploc)
        trialName = trialName(seploc(end)+1:end);
    end
    if isempty(r)
        continue
    end
    % Convert from number of pixels to distance (refPixelLength = reference length/pixels)
    roiData.marking = roiData.marking*refPixelLength;
    % Get the frame count of the reaches marked to match the frame count of the annotations
    numFrames   = length(roiData.frameCount);
    xyCal       = cell(numFrames, 4);
    actionSpec  = cell(numFrames, 3);
    if length(reachingEvents) > 0 % Annotations have events marked
        annotatedFrames = unique([reachingEvents.frameCount]);
        r           = r';
        theta       = theta';
        diffXY      = diffXY'*refPixelLength;
        pos         = intersect(roiData.frameCount, roiFrames', 'rows');
        xyCal(roiFrames, 1) = num2cell(r);
        xyCal(roiFrames, 2) = num2cell(theta);
        xyCal(roiFrames, 3:4) = num2cell(diffXY);
        for actionCount = annotatedFrames
            actionSpec{actionCount, 1} = sprintf('%s ', reachingEvents(find([reachingEvents.frameCount]==actionCount)).action);
            actionSpec{actionCount, 2} = sprintf('%s ', reachingEvents(find([reachingEvents.frameCount]==actionCount)).actionType);
            actionSpec{actionCount, 3} = sprintf('%s ', reachingEvents(find([reachingEvents.frameCount]==actionCount)).consequence);
        end
    end

    data = [data; cat(2, repmat({trialName}, numFrames, 1), num2cell(roiData.frameCount), xyCal, actionSpec, num2cell(roiData.marking'))];
end
data = cell2table(data);
writetable(data, fullfile(pathname, ['rawAnnotations_',datestr(now,30),'.xlsx']),'FileType','spreadsheet', 'WriteVariableNames',true)