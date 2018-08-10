% Albated Pre Trajectory

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/Ablated_Pre.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(1) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(-X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'K-', -X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'W');
  legend off
  hold on
end


X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/Ablated_Pre_16L.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
hold off

xlim([-1, 2])
ylim([0, 2])

% Albated Post Trajectory

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/Ablated_Post.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(2) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(-X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', -X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end


X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/16L_post.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
hold off

xlim([-1, 2])
ylim([0, 2])



% Control Pre Trajectory

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/Control_Pre.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(3) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(-X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', -X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
xlim([-1, 2])
ylim([0, 2])


% Control Post Trajectory

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/Control_Post.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(4) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(-X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', -X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
xlim([-1, 2])
ylim([0, 2])


% Control Pre Trajectory - 16LL

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/16LL_Control_pre.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(3) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
xlim([-1, 2])
ylim([0, 2])


% Control Post Trajectory - 16LL

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_ Ablation_Staircase/16LL_Control_post.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(4) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
xlim([-1, 2])
ylim([0, 2])