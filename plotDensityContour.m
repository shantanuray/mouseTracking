%Program requires pre loading of a csv file with points to plot, xrange and yrange should include ALL points in the csv file
function plotDensityContour(X, num_bins, xrange, yrange, num_colors)
    [bin_count,bin_center] = hist3([X(:,2), X(:,1)],[num_bins, num_bins]);
    bin_center{2} = [xrange(1), bin_center{2}, xrange(2)];
    bin_center{1} = [yrange(1), bin_center{1}, yrange(2)];
    bin_count = [zeros(size(bin_count,1),1),bin_count,  zeros(size(bin_count,1),1)];
    bin_count = [zeros(1,size(bin_count,2));bin_count; zeros(1,size(bin_count,2))];
    if num_colors == 0
        contourf(bin_center{2},bin_center{1},bin_count,'linestyle','none')
    else
        contourf(bin_center{2},bin_center{1},bin_count,num_colors,'linestyle','none')
    end
    % cmap = colormap;
    % cmap(1,:) = ones(1,3);
    colorbar
    xlim(xrange)
    ylim(yrange)
 end