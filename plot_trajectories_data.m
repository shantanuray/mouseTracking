disp('Select the .csv');
[filename, pathname] = uigetfile( ...
             {'*.csv'}, ...
              'Pick .csv file to analyze', ...
              'MultiSelect', 'off');

X = csvread(fullfile(pathname,filename));
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];
DATA = [];
for j = 1:size(init_reach_x, 1)
  
  DATA= [DATA;X(init_reach_x(j, 1):init_reach_x(j, 2),:);[0,0,0]];
end