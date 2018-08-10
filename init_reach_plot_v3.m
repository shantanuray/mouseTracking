% 22UN_OFF

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_Opto_SPR/trajectories_aug2018/22UN_OFF.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(1) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  h1 = plot(f, 'K-', X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.'); %, 'LineStyle','none','Color',[1 1 1]);
  legend off
  hold on
end

hold off
xlim([-0.5, 2.5])
ylim([-2, 2])


% 22UN_ONI
X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_Opto_SPR/trajectories_aug2018/22UN_ONI.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];
h(2) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
hold off
xlim([-0.5, 2.5])
ylim([-2, 2])



% 22UN_ONG

X = csvread('/Users/ayesha/Documents/Ayesha_phd_local storage/Ucn3_Opto_SPR/trajectories_aug2018/22UN_ONG.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

h(3) = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline', 'SmoothingParam', 0.9995);
  plot(f, 'k-', X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
hold off
xlim([-0.5, 2.5])
ylim([-2, 2])