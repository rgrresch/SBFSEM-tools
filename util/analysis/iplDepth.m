function [iplPercent, stats] = iplDepth(Neuron, varargin)
	% IPLDEPTH
    %
    % Description:
    %   Calculates IPL depth based on stratification of single neuron
    %   
    % Syntax:
    %   [iplPercent, stats] = iplDepth(Neuron, INL, GCL);
    %
    % Inputs:
    %   Neuron      Neuron object
    %   INL         INL-IPL Boundary object
    %   GCL         GCL-IPL Boundary object
    % Optional inputs:
    %   numBins     Number of bins for histograms (default = 20)
    % Outputs:
    %   iplPercent  Percent IPL depth for each annotation
    %   stats       Structure containing mean, median, SEM, SD, N
	% 
	% History
	%	7Feb2018 - SSP
    %   19Feb2018 - SSP - Added numBins input
    %   22Oct2018 - SSP - Added boundary markers from cache
	% ---------------------------------------------------------------------

	assert(isa(Neuron, 'sbfsem.core.StructureAPI'),...
		'Input a StructureAPI object');
    
    GCL = sbfsem.builtin.GCLBoundary(Neuron.source, true);
    INL = sbfsem.builtin.INLBoundary(Neuron.source, true);
    
    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'numBins', 20, @isnumeric);
    addParameter(ip, 'plotVariability', false, @islogical);
    addParameter(ip, 'includeSoma', false, @islogical);
    addParameter(ip, 'plotBar', true, @islogical);
    addParameter(ip, 'ax', [], @ishandle);
    addParameter(ip, 'omitOutliers', true, @islogical);
    parse(ip, varargin{:});
    
    numBins = ip.Results.numBins;
    includeSoma = ip.Results.includeSoma;
    ax = ip.Results.ax;
    plotBar = ip.Results.plotBar;
    omitOutliers = ip.Results.omitOutliers;

	nodes = Neuron.getCellNodes;
	% Soma is anything within 20% of the soma radius
    if ~includeSoma
        fprintf('Omitting soma nodes\n');
    	somaRadius = Neuron.getSomaSize(false);
        nodes(nodes.Rum > 0.8*somaRadius, :) = [];
    end

	xyz = nodes.XYZum;

	[X, Y] = meshgrid(GCL.newXPts, GCL.newYPts);
	vGCL = interp2(X, Y, GCL.interpolatedSurface,...
		xyz(:,1), xyz(:,2));

	[X, Y] = meshgrid(INL.newXPts, INL.newYPts);
	vINL = interp2(X, Y, INL.interpolatedSurface,...
		xyz(:,1), xyz(:,2));

	iplPercent = (xyz(:, 3) - vINL) ./ ((vGCL - vINL)+eps);
	iplPercent(isnan(iplPercent)) = [];
    
    if omitOutliers
        iplPercent(iplPercent > 1.2) = [];
        iplPercent(iplPercent < -0.2) = [];
    end
    disp('Mean +- SEM microns (n):');
	printStat(iplPercent');

	stats = struct();
	stats.median = median(iplPercent);
	stats.sem = sem(iplPercent);
	stats.avg = mean(iplPercent);
	stats.n = numel(iplPercent);
	fprintf('Median IPL Depth = %.3g\n', stats.median);

    if isempty(ax)
        ax = axes('Parent', figure());
        hold(ax, 'on');
        figPos(gcf, 0.7, 0.6);
    end
    
    if plotBar
        hist(ax, iplPercent, numBins);
    else
        [a, b] = histcounts(iplPercent, numBins);
        plot(ax, b(1:end-1)+(b(2)-b(1)), a,...
            'Color', 'k', 'Marker', 'o',...
            'MarkerSize', 4.5, 'LineWidth', 1,...
            'Display', sprintf('c%u', Neuron.ID));
    end
    plot(stats.median, 0.1*max(a), 'Marker', '^',...
        'LineWidth', 1,...
        'Color', hex2rgb('ff4040'),...
        'Tag', sprintf('Median %.1f', stats.median));
    plot(stats.avg, 0.1*max(a), 'Marker', '^',...
        'LineWidth', 1,...
        'Color', hex2rgb('334de6'),...
        'Tag', sprintf('Mean %.1f', stats.avg));

    xlim(ax, [-0.25, 1.25]);
    grid(ax, 'on'); hold(ax, 'on');
    set(ax, 'XTick', 0:0.25:1, 'TickDir', 'out',... 
        'XTickLabel', {'INL', 'off', 'IPL', 'on', 'GCL'},...
        'TitleFontWeight', 'normal');
    
    title(ax, sprintf('c%u Stratification', Neuron.ID));
	ylabel(ax, 'Number of annotations');
	% xlabel(ax, 'Percent IPL Depth');
    
    if ip.Results.plotVariability
    	figure();
        hist(vINL-vGCL, numBins); hold on;
        title(sprintf('Variability in total IPL depth for c%u', Neuron.ID));
        xlabel('IPL depth (microns)');
        ylabel('Number of annotations');
    end
    
    y = get(ax, 'YLim');
    rectangle(ax, 'Position', [-0.25, 0, 0.25, y(2)+1],...
        'FaceColor', [0, 0, 0, 0.1], 'EdgeColor', 'none');
    rectangle(ax, 'Position', [1, 0, 0.25, y(2)+1],...
        'FaceColor', [0, 0, 0, 0.1], 'EdgeColor', 'none');
    set(ax, 'YLim', y);