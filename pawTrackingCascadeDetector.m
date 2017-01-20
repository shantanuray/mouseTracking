%% Motion-Based Mouse Arm Tracking

function pawTrackingCascadeDetector()

% Create System objects used for reading video, detecting moving objects,
% and displaying the results.
obj = setupSystemObjects();
backImg = getBackgroundImage();
frameCount = 0;
% Detect moving objects, and track them across video frames.
outcome = table;
while ~isDone(obj.reader)
    frame = readFrame();
    frameCount = frameCount+1;
    mask = deleteBackground(backImg, frame);
    bboxes = detectObjects(mask);
    outcome.frameCount{i,1} = frameCount;
    outcome.bboxes{i,1} = bboxes;
    if ismpty(bboxes)
        outcome.detected(i,1) = false;
    else
        outcome.detected(i,1) = true;
    end
    displayTrackingResults();
end


%% Create System Objects
% Create System objects used for reading the video frames, detecting
% paw, and displaying results.

    function obj = setupSystemObjects()
        % Initialize Video I/O
        [fileName, pathName] = uigetfile({'*.mp4;*.avi', 'Video Files (*.mp4, *.avi)'});
        videoFile = fullfile(pathName, fileName);
        % Create objects for reading a video from a file, drawing the tracked
        % objects in each frame, and playing the video.
        
        % Create a video file reader.
        obj.reader = vision.VideoFileReader(videoFile);
        
        % Create two video players, one to display the video,
        % and one to display the foreground mask.
        obj.videoPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);
        obj.maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);
        
        % Create System objects for foreground detection and blob analysis
        
        % The foreground detector is used to segment moving objects from
        % the background. It outputs a binary mask, where the pixel value
        % of 1 corresponds to the foreground and the value of 0 corresponds
        % to the background. 
        
        obj.detector = vision.CascadeObjectDetector('pawDetector.xml');
    end

%% Read a Video Frame
% Read the next video frame from the video file.
    function frame = readFrame()
        frame = obj.reader.step();
    end

%% Calculate the background image
% Average out the images to get background image
    function backImg = getBackgroundImage()

        disp('Calculating background image...')
        % Initialize background image
        backImg = readFrame();
        frameCount = 1;
        while ~isDone(obj.reader)
            % Read next frame
            frame = readFrame();
            % Convert to gray
            frame = rgb2gray(frame);
            frameCount = frameCount+1;  
            % Update background image
            backImg = (1/frameCount).*frame + ((frameCount - 1)/frameCount) .* backImg;
        end
        obj.reader.reset();

        % Show background image
        h2=figure;
        imshow(backImg);
        pause(2);
        close(h2);
    end

%% Delete the background image from frame
    function img = deleteBackground(backImg, frame)

        img = rgb2gray(frame);
        img = img - backImg;
        img(sign(img) == -1) = 0;
        img = 2*img; 
    end

%% Detect Objects
% The |detectObjects| function returns the bounding boxes of the detected paw
%
% The function performs motion segmentation using the detector trained using
% pawDetector.xml   

    function bboxes = detectObjects(frame)
        % Perform paw detection using detector trained on pawDetector.xml
        bboxes = step(obj.detector, frame);
    end

%% Display Tracking Results
% The |displayTrackingResults| function draws a bounding box and label ID 
% for each track on the video frame and the foreground mask. It then 
% displays the frame and the mask in their respective video players. 

    function displayTrackingResults()
        % Convert the frame and the mask to uint8 RGB.
            frame = im2uint8(frame);
            mask = uint8(repmat(mask, [1, 1, 3])) .* 255;
            
            obj.maskPlayer.step(mask);        
            obj.videoPlayer.step(frame);

            if ~isempty(bboxes)

                bbox1 = bboxes(bboxes(:,2)>485,:);
                bbox1 = bbox1(bbox1(:,2)<550,:);
                bbox1 = bbox1(bbox1(:,3)>=30,:);
                bbox1 = bbox1(bbox1(:,4)>=25,:);

                if ~isempty(bbox1)
                    ids = 1:size(bbox1,1);
                    labels = cellstr(int2str(ids'));

                    % Display the mask and the frame.
                    frame = insertObjectAnnotation(frame, 'rectangle', bbox1, labels);
                    
                    % Draw the objects on the mask.
                    mask = insertObjectAnnotation(mask, 'rectangle', bbox1, labels);
                end
            end
            obj.maskPlayer.step(mask);        
            obj.videoPlayer.step(frame);
    end

end