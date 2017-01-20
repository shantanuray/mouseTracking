%% Motion-Based Mouse Arm Tracking

function pawTrackingByBlob()

% Create System objects used for reading video, detecting moving objects,
% and displaying the results.
obj = setupSystemObjects();

frameCount = 0;
% Detect moving objects, and track them across video frames.
while ~isDone(obj.reader)
    frame = readFrame();
    frameCount = frameCount+1;
    [centroids, bboxes, mask] = detectObjects(frame);
    [predictedLabels, predictedBboxes] = classifyObjects();
    displayTrackingResults();
end
release(obj.videoPlayer); % close the input file
release(obj.videoFWriter); % close the output file

release(obj.maskPlayer); % close the input file
release(obj.maskFWriter); % close the output file


%% Create System Objects
% Create System objects used for reading the video frames, detecting
% foreground objects, and displaying results.

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

        obj.videoFWriter = vision.VideoFileWriter(fullfile(pathName, 'rawVideoWLabel.mp4'), ...
            'FrameRate', 4, 'FileFormat', 'MPEG4');
        obj.maskFWriter = vision.VideoFileWriter(fullfile(pathName, 'maskVideoWLabel.mp4'), ...
            'FrameRate', 4, 'FileFormat', 'MPEG4');
        
        % Create System objects for foreground detection and blob analysis
        
        % The foreground detector is used to segment moving objects from
        % the background. It outputs a binary mask, where the pixel value
        % of 1 corresponds to the foreground and the value of 0 corresponds
        % to the background. 
        
        obj.detector = vision.ForegroundDetector('NumGaussians', 3, ...
            'NumTrainingFrames', 30);

        % Use SVM classifier trained earlier for classification
        obj.classifier = load('svmClassifier.mat');
        
        % Connected groups of foreground pixels are likely to correspond to moving
        % objects.  The blob analysis System object is used to find such groups
        % (called 'blobs' or 'connected components'), and compute their
        % characteristics, such as area, centroid, and the bounding box.
        
        obj.blobAnalyser = vision.BlobAnalysis('BoundingBoxOutputPort', true, ...
            'AreaOutputPort', true, 'CentroidOutputPort', true, ...
            'MinimumBlobArea', 50);
    end

%% Read a Video Frame
% Read the next video frame from the video file.
    function frame = readFrame()
        frame = obj.reader.step();
    end

%% Detect Objects
% The |detectObjects| function returns the centroids and the bounding boxes
% of the detected objects. It also returns the binary mask, which has the 
% same size as the input frame. Pixels with a value of 1 correspond to the
% foreground, and pixels with a value of 0 correspond to the background.   
%
% The function performs motion segmentation using the foreground detector. 
% It then performs morphological operations on the resulting binary mask to
% remove noisy pixels and to fill the holes in the remaining blobs.  

    function [centroids, bboxes, mask] = detectObjects(frame)
        
        % Detect foreground.
        mask = obj.detector.step(frame);
        
        % Apply morphological operations to remove noise and fill in holes.
        mask = imopen(mask, strel('rectangle', [3,3]));
        % mask = imclose(mask, strel('rectangle', [5, 5])); 
        % mask = imfill(mask, 'holes');
        
        % Perform blob analysis to find connected components.
        [~, centroids, bboxes] = obj.blobAnalyser.step(mask);
    end

    function [predictedLabels, predictedBboxes] = classifyObjects()
        predictedLabels = [];
        predictedBboxes = [];
        if ~isempty(bboxes)
            % Pick bboxes only of a particular size
            % centroids = centroids(bboxes(:,3)>=30,:);
            % centroids = centroids(bboxes(:,4)>=25,:);
            bboxes = bboxes(bboxes(:,3)>=30,:);
            bboxes = bboxes(bboxes(:,4)>=25,:);
            
            for i = 1:size(bboxes,1)
                blobFrame = frame(bboxes(i,2)+bboxes(i,4)-64+1:bboxes(i,2)+bboxes(i,4), ...
                    bboxes(i,1)+1:bboxes(i,1)+64,...
                    :);

                % blobFrame = imbinarize(rgb2gray(blobFrame));
                
                frameFeatures = extractHOGFeatures(blobFrame,'CellSize',[4,4]);

                % Predict label.
                [label, prob] = predict(obj.classifier.classifier, frameFeatures);
                if 1-prob > 2/3
                    predictedLabels(i) = label;
                    predictedBboxes(i,:) = bboxes(i,:);
                end
            end
        end
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

            if ~isempty(predictedBboxes)

                % bbox1 = bboxes(bboxes(:,2)>485,:);
                % bbox1 = bbox1(bbox1(:,2)<550,:);
                % bbox1 = bbox1(bbox1(:,3)>=30,:);
                % bbox1 = bbox1(bbox1(:,4)>=25,:);

                % ids = 1:size(bbox1,1);
                % labels = cellstr(int2str(ids'));
                labels = cellstr(int2str(predictedLabels'));

                % Display the mask and the frame.
                frame = insertObjectAnnotation(frame, 'rectangle', predictedBboxes, labels);
                
                % Draw the objects on the mask.
                mask = insertObjectAnnotation(mask, 'rectangle', predictedBboxes, labels);

                % write video
                step(obj.videoFWriter, frame);
                step(obj.maskFWriter, mask);
            end
            obj.maskPlayer.step(mask);        
            obj.videoPlayer.step(frame);
    end

end