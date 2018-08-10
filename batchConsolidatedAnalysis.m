function eventData = batchConsolidatedAnalysis(filename, pathname)
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
      annotationFile = filename;
  elseif ischar(filename)
      filecount = 1;
      annotationFile{1} = filename;
  else
      error('File not found')
  end

  refTargetName = 'pellet';
  refBodyPartName = 'hand';
  modeFlag = 'background';
  writeFrameCount = true;
  reachCounter = 0;

  for i = 1:filecount
    r = [];
    theta = [];
    diffXY = [];
    outcome = {};
    traceVideoFile = {};
    refXYPosition = [];
    roiXYPosition = [];
    disp(['Processing file # ', num2str(i), ': ', annotationFile{i}])
    load(fullfile(pathname, annotationFile{i}), 'videoFile', 'roiData', 'reachingEvents', 'refPixelLength'); 
    [r, theta, diffXY, refXYPosition, roiXYPosition, roiFrames] = analyzeMouseAnnotation(roiData, reachingEvents, videoFile,...
        'RefTargetName', refTargetName, 'RefBodyPartName', refBodyPartName,... 
        'ModeFlag', modeFlag,... 
        'VideoMux', [false false false true], 'WriteFrameCount', writeFrameCount);
    
    [pathName, trialName, vidExt] = fileparts(videoFile);
    % For windows
    seploc=findstr(trialName,'\');
    if ~isempty(seploc)
        trialName = trialName(seploc(end)+1:end);
    end
    if isempty(r)
        warning(['No annotations in ' trialName])
        continue;
    end

    % Convert from number of pixels to distance (refPixelLength = reference length/pixels)
    roiData.marking = roiData.marking*refPixelLength;
    r           = r*refPixelLength;
    theta       = theta;
    diffXY      = diffXY*refPixelLength;

    frameCount=[reachingEvents.frameCount];
    action = {reachingEvents.action};

    initializeFrameCount = sort(frameCount(find(strcmpi(action, 'initialize'))));
    crossdoorwayFrameCount = sort(frameCount(find(strcmpi(action, 'cross doorway'))));
    graspFrameCount = sort(frameCount(find(strcmpi(action, 'grasp'))));
    retrieveFrameCount = sort(frameCount(find(strcmpi(action, 'retrieve'))));
    laserlightonFrameCount = sort(frameCount(find(strcmpi(action, 'laser light on'))));
    laserlightoffFrameCount = sort(frameCount(find(strcmpi(action, 'laser light off'))));
    ledcounterFrameCount = sort(frameCount(find(strcmpi(action, 'led counter'))));
    ledcounter = sort([reachingEvents(find(strcmpi(action, 'led counter'))).counterNumber]);

    referenceEvent = 'Reach';
    referenceFrameCount = sort(frameCount(find(strcmpi(action, referenceEvent))));
    if i == 1
      eventData(1,:) = [{'Trial','Index','Initialize','Cross Doorway','Reach','Grasp','Retrieve',...
      'Laser Light On','Laser Light Off',...
      'LED Counter Frame','LED Counter',...
      'Relative Distance','Relative Angle of Approach','Relative X','Relative Y'},...
      reshape([strcat(roiData.roi, {' - Absolute X'}); strcat(roiData.roi, {' - Absolute Y'}); strcat(roiData.roi, {' - Likelihood'})], 1, 18)];
    end

    for i = 1:length(referenceFrameCount)
      reachCounter = reachCounter+1;
      eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Trial'))} = trialName;
      eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Index'))} = reachCounter;
      eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Reach'))} = referenceFrameCount(i);
      if ~isempty(laserlightonFrameCount)
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Laser Light On'))} = laserlightonFrameCount(1);
      end
      if ~isempty(laserlightoffFrameCount)
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Laser Light Off'))} = laserlightoffFrameCount(1);
      end
      if ~isempty(ledcounterFrameCount)
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'LED Counter Frame'))} = ledcounterFrameCount(1);
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'LED Counter'))} = ledcounter(1);
      end
      tmpFrameCount = initializeFrameCount(initializeFrameCount<=referenceFrameCount(i));
      if ~isempty(tmpFrameCount)
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Initialize'))} = tmpFrameCount(end);
      end
      tmpFrameCount = crossdoorwayFrameCount(crossdoorwayFrameCount<=referenceFrameCount(i));
      if ~isempty(tmpFrameCount)
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Cross Doorway'))} = tmpFrameCount(end);
      end
      
      if isempty(find(referenceFrameCount>referenceFrameCount(i)))
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Grasp'))} = graspFrameCount(graspFrameCount>=referenceFrameCount(i));
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Retrieve'))} = retrieveFrameCount(retrieveFrameCount>=referenceFrameCount(i));
      else
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Grasp'))} = graspFrameCount(graspFrameCount>=referenceFrameCount(i) & (graspFrameCount<referenceFrameCount(find(referenceFrameCount>referenceFrameCount(i)))));
        eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Retrieve'))} = retrieveFrameCount(retrieveFrameCount>=referenceFrameCount(i) & (retrieveFrameCount<referenceFrameCount(find(referenceFrameCount>referenceFrameCount(i)))));
      end

      eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Relative Distance'))} = r(find(roiFrames==referenceFrameCount(i)));
      eventData{reachCounter+1,find(strcmpi(eventData(1,:),'Relative Angle of Approach'))} = theta(find(roiFrames==referenceFrameCount(i)));
      eventData(reachCounter+1,[find(strcmpi(eventData(1,:),'Relative X')),find(strcmpi(eventData(1,:),'Relative Y'))]) = num2cell(reshape(diffXY(:,find(roiFrames==referenceFrameCount(i))),1,2));

      eventData(reachCounter+1,[find(strcmpi(eventData(1,:),'Relative Y'))+1:end]) = num2cell(reshape(roiData.marking(:,find(roiData.frameCount==referenceFrameCount(i))),1,18));

    end
  end
  eventData = cell2table(eventData);
  writetable(eventData, fullfile(pathname, ['consolidateAnnotations_',datestr(now,30),'.xlsx']),'FileType','spreadsheet', 'WriteVariableNames',true)
end