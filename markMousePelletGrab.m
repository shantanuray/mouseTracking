function [pelletPosition, pawPosition, grabResult, isTremorCase, videoFile] = markMousePelletGrab(varargin)
% [pelletPosition, pawPosition, grabResult, isTremorCase, videoFile] = markMousePelletGrab;
% 
% Guides user to mark the mouse paw as it tries to grab the pellet
% The program does not detect paw or pellet automatically but
% instead guides the user to identify the required inputs.
% Steps of the program:
%   1. Identify pellet: At the start of the program, user is asked
%       to identify the pellet. User should only identify the target
%       pellet that the mouse was trying to grab in the task. There can 
%       be only one target pellet for a given video currently
%       TODO: Handle multiple targets
%   2. Identify paw: In every subsequent frame, user is asked to identify
%       the position of the paw
%   3. Identify and classify grab: At each stage the user is also asked if
%       the mouse grabbed the pellet and if so, classify it as 'Overreach',
%       'Underreach', or a prehension. If it is a prehension, then user is
%       further asked to provide a label for type of prehension.
%   4. Identify if there was tremor: At the end of the analysis before quitting
%       user is asked if the user saw tremor
% 
% Outputs:
%   - pelletPosition:   Position of the target pellet identified 
%                       at the start of the program
%                       Structure with fields ('position','centroid',imageFile','frameCount')
%   - pawPosition:      Position of the paw in every frame
%                       Structure with fields ('position','centroid','imageFile','frameCount')
%   - grabResult:       The outcome of the grab:
%                       * Overreach
%                       * Underreach
%                       * Prehension (user suggested label for prehension)
%                       Structure with fields ('outcome','position','centroid','imageFile','frameCount')
%   - isTremorCase:     Was a tremor identified by the observer in the mouse grab
%                       logical (0,1)
% Usage:
% [...] = markMousePelletGrab; 
%   User will be asked to point the video file
% [...] = markMousePelletGrab('VideoFile', videoFile);
%   Provide video file. obj.standardImageSize assumed to be [64 x 64 pixels]
% [...] = markMousePelletGrab('VideoFile', videoFile, 'StandardImageSize', standardImageSize);
%   Provide video file and provide obj.standardImageSize

%% TODO Provide support for image files
% [...] = markMousePelletGrab('RawImageFolder', fpath, 'StandardImageSize', standardImageSize);
%   Provide path where the image files are stored

p = readInput(varargin);
[obj, pelletPosition, pawPosition, grabResult, isTremorCase, videoFile] = initializeSystem(p);

%% Start processing
h1=figure;
% Put figure on the top left corner
% Adjust size for optimal viewing. Remove toolbars
% Note the original size is 1080 x 1920
set(h1,'Position',[321 350 640 360], 'Toolbar','None', 'Menubar','None');     
frameCount = 0;

h0=figure;
set(h0,'Position',[0 350 320 180], 'Toolbar','None', 'Menubar','None');   

h2=figure;
set(h2,'Position',[961 350 320 180], 'Toolbar','None', 'Menubar','None');

%% Mark the pellet
% Read first frame to mark the pellet
frame = readFrame(obj.video);
oldframe = zeros(size(frame));
nextframe = zeros(size(frame));
frameCount = frameCount+1;
h1=imdisplay(frame,h1);
disp('Mark the target pellet in the image displayed');
% Call imageMark for the given frame to mark the pellet
[position, pelletCentroid, pelletImage] = imageMark(frame);
fileName = saveImage(pelletImage, obj.imageFolder{1,1}, [obj.savePrefix,'_',int2str(frameCount)]);
pelletPosition = struct('position', position,'centroid',pelletCentroid,'imageFile',fileName,'frameCount',frameCount);
reply = '';
while ~strcmpi(reply,'x')
    %% Continue the process of identification
    % Now we start identifying the paw in each frame
    if hasFrame(obj.video)
        % Read frame
        nextframe = readFrame(obj.video);
        h2=imdisplay(nextframe,h2);
    else
        nextframe = [];
        close(h2);
    end
    h1=imdisplay(frame,h1);
    reply = input('Mark the paw? [Yes - Any key | No - N | Exit - X]    ','s');
    if strcmpi(reply,'x')
        break;
    end
    if ~strcmpi(reply, 'n')
        [position, centroid, imgMatch] = imageMark(frame);
        fileName = saveImage(imgMatch, obj.imageFolder{2,1}, [obj.savePrefix,'_',int2str(frameCount)]);
        pawPosition = [pawPosition; struct('position',position,'centroid',centroid,'imageFile',fileName,'frameCount',frameCount)];
        
        reply = '';
        outcome = '';
        while isempty(reply)
            reply = input(['\nDo you wish to continue to next image [Enter]\n',...
                'Or\nSpecify a mouse grab using options - [1 or 2 or 3] \n',...
                '1 => Overreach\n',...
                '2 => Underreach\n',...
                '3 => Prehension\n'],'s');
            switch reply
            case '1'
                outcome = 'overreach';
            case '2'
                outcome = 'underreach';
            case '3'
                % Provide input as to what type of prehension it was
                outcome = lower(input('How would you classify the prehension - Provide a single word: ', 's'));
                % Remove spaces - Converting to single word
                outcome = strrep(outcome,' ','');
                %% TODO Provide previously used label choices as reference
            case ''
                reply = 'next';
            otherwise
                reply = '';
                disp('Warning: You have marked an incorrect input. Please try again.')
            end
        end
        if ~isempty(outcome)
            fileName = saveImage(imgMatch, obj.imageFolder{2,1}, [obj.savePrefix,'_',int2str(frameCount),'_',outcome]);
            grabResult = [grabResult; ...
            struct('outcome',outcome,'position',pawPosition(end).position,...
                'centroid',pawPosition(end).centroid,'imageFile',fileName,'frameCount',pawPosition(end).frameCount)];
        end
    end

    oldframe = frame;
    h0=imdisplay(oldframe,h0);

    if ~isempty(nextframe)
        frame = nextframe;
        frameCount = frameCount+1;
    else
        close(h0);close(h1);
        break;
    end
end
tremorFlag = input('Did you notice tremor in the video? [Y | N]     ', 's');
isTremorCase = lower(tremorFlag)=='y';
%% TODO Provide support for image files
% % Create imageDatastore from the raw images
% rawImageSet = imageDatastore(fpath, 'IncludeSubfolders', false,'LabelSource', 'foldernames');
% numRawImages = numel(rawImageSet.Files);
% for i = 1:numRawImages
%     % Read frame
%     img = readimage(rawImageSet, i);
%     % Call imageMarkSave for the given frame/image to mark object for classification
%     matchCount = imageMarkSave(img, matchCount);
%     contFlag = input('Do you wish to keep going? [Enter - Y | N]: ', 's');
%     if strcmpi(contFlag,'n')
%         break;
%     end
% end
[matDir,matPrefix]=fileparts(videoFile);
save(fullfile(matDir,[matPrefix,'.mat']), 'pelletPosition', 'pawPosition', 'grabResult', 'isTremorCase', 'videoFile');
return;

    %% Read input
    function p = readInput(input)
        p = inputParser;
        defaultVideoFile = '';
        defaultStandardImageSize = [64,64];
        defaultRawImageFolder = '';

        addParameter(p,'VideoFile',defaultVideoFile, @ischar);
        addParameter(p,'StandardImageSize',defaultStandardImageSize, @isinteger);

        %% TODO Provide support for image files
        % addParameter(p,'RawImageFolder',defaultRawImageFolder, @ischar);

        parse(p, input{:});
    end

    %% Initialize and setup system objects and outputs
    function [obj, pelletPosition, pawPosition, grabResult, isTremorCase, videoFile] = initializeSystem(p)

        % Get folder where the training images are stored
        disp('Select video for marking mouse grabs (*.mp4, *.avi)');
        if isempty(p.Results.VideoFile)
            [fileName, fpath] = uigetfile({'*.mp4;*.avi', 'Select video for marking mouse grabs (*.mp4, *.avi)'});
            videoFile = fullfile(fpath, fileName);
            [~, obj.savePrefix] = fileparts(fileName);
        else
            videoFile = p.Results.VideoFile;
            [fpath, obj.savePrefix] = fileparts(videoFile);
        %% TODO Provide support for image files
        % elseif ~isempty(p.Results.RawImageFolder)
        %     rawImageFolder = p.Results.RawImageFolder;
        %     fpath = rawImageFolder;
        %     obj.savePrefix = '';
        
        end

        if ~isempty(videoFile)
            % Read video file
            obj.video = VideoReader(videoFile);
        else
            error('Could not find video. Please check and try again');
        end

        obj.standardImageSize = int16(p.Results.StandardImageSize);

        %% Initialize
        % Prepare folders for storing matches
        %   - Pellet
        %   - Paw
        folderTypes = {'Pellet', 'Paw'};
        for i = 1:length(folderTypes)
            obj.imageFolder{i,1} = fullfile(fpath,'matches',folderTypes{i});
            if ~isdir(obj.imageFolder{i,1})
                mkdir(obj.imageFolder{i,1});
            end
        end

        obj.imgMatch = zeros(obj.standardImageSize);

        % Initialize outputs
        pelletPosition = struct([]);
        pawPosition = struct([]);
        grabResult = struct([]);
        isTremorCase = logical(0);
    end

    % For the given frame/image, ask the user to identify
    % and mark objects
    % Return position and and the marked image (standard size)
    function [position, centroid, imgMatch] = imageMark(img)
        % Ask user to draw rectangle to mark object
        position = int16(getrect);
        % Get marked image (size as marked)
        imgMarked = getImageMarked(img, position);
        
        %% Now we will select a region of standard image size (def 64 x 64) around
        % the centroid of the marked region and save this
        
        %% Binarize the marked image
        imgBin = imbinarize(rgb2gray(imgMarked));

        %% Extract the centroid (if marked properly, there should be only one centroid,
        % i.e. [x y] coordinates of the centroid of the marked image
        % regionprops returns a structure as imageProp.Centroid relative to the marked image
        imageProp = regionprops(imgBin,'centroid'); 
        centroids = int16(cat(1, imageProp.Centroid)); % Convert the structure to an array of int
        % If more than one centroid is detected, choose the centroid that is closest to the 
        % center of the select image [size(imgBin)/2]
        centroids = centroids(abs([size(imgBin,1)/2-centroids(:,1), size(imgBin,2)/2-centroids(:,2)])==...
          min(abs([size(imgBin,1)/2-centroids(:,1), size(imgBin,2)/2-centroids(:,2)]),[],1));
        % When there is a single centroid, above function returns a row vector as required
        % When there multiple centroids, even though the above returns the correct centroid location,
        %   it returns it as a column vector. Convert by default to row vector as required
        % TODO Check why sometimes length(centroids)~=2. For now, continue
        if length(centroids)~=2
            disp(imageProp);
            disp(size(imgBin,1));
            centroid=[];
            imgMatch=[];
            return;
        end
        centroid=reshape(centroids,[1 2]); 

        %% Calculated position of region wrt original image
        % 1. Calculate location of centroid wrt original image
        %   centroids = centroids + position(1:2);          
        % 2. Then mark the top left corner of 100 x 100 region around centroid
        %   position(1:2) = [centroids(1)-50, centroids(2)-50];
        % 3. Then finally mark the width and height of the 100 x 100 region
        %   position(3:4) = [100 100];
        position = [[centroid + position(1:2) - int16(obj.standardImageSize/2)],obj.standardImageSize];
        % Position of centroid with respect to this standard size image is the center of the image
        centroid=int16(obj.standardImageSize/2);
        % Get marked image (standard image size around marked image centroid)
        imgMatch = getImageMarked(img, position);
    end

    function fileName = saveImage(img, fpath,fprefix)
        if ~isempty(img)
            fileName = fullfile(fpath, [fprefix,'.tiff']);
            %% Write image
            imwrite(img, fileName, 'TIFF');
        else
            fileName = '';
        end
    end

    %% For the given box, [x y width height], return the selected image with actual
    % coordinates [row(1):row(end), column(1):column(end)]
    function imgMarked = getImageMarked(img, position)
        imgMarked = img(position(2):position(2)+position(4)-1, position(1):position(1)+position(3)-1,:);
    end

    function h = imdisplay(img,h)
        if ~ishandle(h)
            % If the figure was closed, reopen it
            h = figure;
            % Put figure on the top left corner
            % Adjust size for optimal viewing. Remove toolbars
            % Note the original size is 1080 x 1920
            set(h,'Position',[0 350 800 450], 'Toolbar','None', 'Menubar','None');  
        else
            figure(h);
        end
        % Show the image and fit it to the figure window
        imshow(img,'InitialMagnification','fit','Border','tight');
    end
end