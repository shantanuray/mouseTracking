function [frames,backImg,elements, files] = backgroundSubtract(video)

dirstruct = dir(folder);

[sorted_names,sorted_index] = sortrows({dirstruct.name}');

%Then eliminate all but the .tif files
filecount = 0;
fileindices = [];
for i=1:length(sorted_names)
    if ~isdir(sorted_names{i})
        [path name ext] = fileparts(sorted_names{i});
        
        if (strcmp(ext,'.tif')|strcmp(ext,'.tiff'))
            filecount = filecount+1;
            fileindices = [fileindices i];
        end
    end
end

frames = filecount;
diffs = zeros(frames-1,1);

if filecount > 0
    files = cell(filecount,1);
    for i=1:filecount
        files{i} = sorted_names{fileindices(i)};
    end
else
    files = {};
end  

disp('Establishing inter-image change threshold...')

%flag = 0;

for n = 2:frames
    
    if mod(n,100) == 0
        disp(['Identifying movement in frames. ' int2str(n) ' done out of ' int2str(frames)])
    end
    
    try
        img1 = (imread(files{n}));
        % img1 = imcomplement(rgb2gray(img1));
        % img1(1:y_offset,:)=0; %cut off lights
        % img1 = imadjust(img1, [.08,.6],[0,1]);
        
        img2 = (imread(files{n-1}));
        % img2 = imcomplement(rgb2gray(img2));
        % img2(1:y_offset,:)=0; %cut off lights
        % img2 = imadjust(img2, [.08,.6],[0,1]);

        % img1 = double(img1);
        % img2 = double(img2);
        
        % img1(img1>pixel_intensity_threshold)=0;
        % img2(img2>pixel_intensity_threshold)=0;
        
        % theChange = sum(sum(sum(abs(img1 - img2))));
        theChange = 1 - corr2(img1, img2);
        diffs(n-1) = theChange;
    catch
        %if flag == 0
            %flag = 1;
            disp(['     ERROR: "img' int2str(n-1) '.tif" does not exist!'])
            frames = n-1;
        %end
        break
    end
    
end

average = mean(diffs);
sigma   =  std(diffs);

disp('Rendering background image...')

imgDims = size(img1);

backImg = zeros(imgDims,'uint8');

imageCount = 0;
elements   = [];
h1 = figure;
for n = 2:frames
    
    img1 = (imread(files{n}));
    img1 = rgb2gray(img1);
    % img1(1:y_offset,:)=0; %cut off lights
    % img1 = imadjust(img1, [.08,.6],[0,1]);
    
    img2 = (imread(files{n-1}));
    img2 = rgb2gray(img2);
    % img2(1:y_offset,:)=0; %cut off lights
    % img2 = imadjust(img2, [.08,.6],[0,1]);

    % img2 = imadjust(img2, [.08,.6],[0,1]);
    % img1 = double(img1);
    % img2 = double(img2);
    
    % img1(img1>pixel_intensity_threshold)=0;
    % img2(img2>pixel_intensity_threshold)=0;
    
    % theChange = sum(sum(sum(abs(img1 - img2))));
    theChange = 1 - corr2(img1, img2);
    
    if theChange > (average + (1 * sigma))
        
        disp(['Including frame #' int2str(n)]);
        
        imshow(img1);
        imageCount = imageCount + 1;
        backImg    = (1/imageCount).*img1 + ((imageCount - 1)/imageCount) .* backImg;
        elements = [elements ; n];
        
    end
end

disp(['Images used for background image: ' int2str(imageCount) ' out of ' int2str(frames)])

disp('Saving new images in: ')
disp(['     ' folder filesep 'Paws']);

mkdir(folder,'Paws');

% select area of interest
h2=figure;
imshow(backImg);

% [pind,xs,ys] = selectdata('selectionmode','Rect');
disp('Select area of interest as a rectangle on the background image');
rect = getrect;
xs = [rect(1), rect(1)+rect(3), rect(1)+rect(3), rect(1), rect(1)];
ys = [rect(2), rect(2), rect(2)+rect(4), rect(2)+rect(4), rect(2)];

BW = poly2mask(xs,ys,size(backImg, 1),size(backImg, 2));
hold on;
plot(xs,ys,'r.');
pause(2);
close(h2);

% backImg(BW)=0;
disp('Displaying background image');
imshow(backImg);

%%%% end select region in frames to set to zero
h3 = figure;
for n = 1:frames
    
    if mod(n,100) == 0
        disp(['Number of frames processed: ' int2str(n) ' out of ' int2str(frames)])
    end
    
    img = (imread(files{n}));
    img = rgb2gray(img);
    img = img - backImg;
%     % img = 2 .* img;
    img(sign(img) == -1) = 0;
%     img = imcomplement(img);
    imshow(img)
    imwrite(img,[folder filesep 'Paws' filesep 'paws' int2str(n-1) '.tif'],'TIFF');
    
end


disp(['All ' int2str(frames) ' images saved.'])
disp('Saving background image as:')
disp(['     ' folder filesep 'Paws' filesep 'backImg.tif'])
disp(['     ' folder filesep 'Paws' filesep 'backImg.mat'])

imwrite(uint8(backImg), [folder filesep 'Paws' filesep 'backImg.tif'], 'TIFF');
save([folder filesep 'Paws'  filesep 'backImg.mat'],'backImg');

disp('Background subtraction done.')




