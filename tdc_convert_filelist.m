% WARNING: this code is 100% ChatGPT o1 generated.
% For how this code work, and this was generated, see the conversation archive below:
% https://chatgpt.com/share/67773c78-6ea4-8006-a362-337b153c0aea
% 

function tdc_convert_filelist(file_list, mon_dir, min_file_size_mb, min_counts_hz, mov_mean_len, do_plots)
% tdc_convert_filelist(file_list, mon_dir, min_file_size_mb, min_counts_hz, mov_mean_len, do_plots)
%
% Convert a *specific* list of TDC output files in `mon_dir` into TXY format,
% replicating default behavior from tdc_auto_convert.m—but skipping the 
% continuous monitoring loop and skipping any sound outputs.
%
% Inputs (all optional except `file_list`):
%   file_list           : cell array of filenames (strings), e.g. {'d123.txt','d124.txt',...}
%   mon_dir            : directory containing TDC *.txt files
%   min_file_size_mb   : minimum file size (MB) required to convert
%   min_counts_hz      : minimum counts/second for an alert (not used for sounds here)
%   mov_mean_len       : length of the rolling average count buffer
%   do_plots           : (bool) whether to generate and save a counts-trend plot
%
% Example:
%   file_list = {'d123.txt','d124.txt'};
%   tdc_convert_filelist(file_list);   % uses defaults, no plots
%   tdc_convert_filelist(file_list, [], [], [], [], true);  % uses defaults, with plotting
%
% -------------------------------------------------------------------------
% Default values as in tdc_auto_convert.m
mon_dir_default = 'C:\Users\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output';
if ~exist('mon_dir','var') || isempty(mon_dir)
    warning('mon_dir is undefined. Setting to default: %s',mon_dir_default);
    mon_dir = mon_dir_default;
end

if ~exist('min_file_size_mb','var') || isempty(min_file_size_mb)
    min_file_size_mb = 0;  % MB
    warning('min_file_size_mb is undefined. Setting to default: %d', min_file_size_mb);
end

if ~exist('min_counts_hz','var') || isempty(min_counts_hz)
    min_counts_hz = 700;
    warning('min_counts_hz is undefined. Setting to default: %.1f', min_counts_hz);
end

if ~exist('mov_mean_len','var') || isempty(mov_mean_len)
    mov_mean_len = 30;
    warning('mov_mean_len is undefined. Setting to default: %d', mov_mean_len);
end

if ~exist('do_plots','var') || isempty(do_plots)
    do_plots = false;
    % no warning needed if user never specified
end
% -------------------------------------------------------------------------

% Ensure file_list is a cell array of strings
if isempty(file_list) || ~iscell(file_list)
    error('file_list must be a non-empty cell array of filenames.');
end

% Create output directory if needed
out_dir = fullfile(mon_dir,'out');
if ~isfolder(out_dir)
    mkdir(out_dir);
end
anal_out_dir = fullfile(out_dir,'monitor');
if ~isfolder(anal_out_dir)
    mkdir(anal_out_dir);
end

% Initialize rolling buffers if do_plots is true
lenLongTrendPlot = 500;
count_circ_buffer = NaN(mov_mean_len,1);
trend_circ_buffer = NaN(lenLongTrendPlot,1);

if do_plots
    figure(101); %#ok<*UNRCH> 
    clf;
    h = gca;
    hplot_trend = plot(trend_circ_buffer, ...
        'YDataSource','trend_circ_buffer', ...
        'Color','b','LineStyle','--','Marker','d','LineWidth',2);
    title('Total hit-count trend');
    ylabel('Tot counts');
    set(gcf, 'Color', [1,1,1]);
    grid on; 
    grid minor;

    % Make the major grid lines more visible
    h.GridLineStyle='-';
    h.GridAlpha=1;
    h.GridColor=[0,0,0];
    % Minor grid lines
    h.MinorGridLineStyle='-';
    h.MinorGridAlpha=0.1;
    h.MinorGridColor=[0,0,0];
end

fprintf('\nConverting %d file(s) in %s\n', numel(file_list), mon_dir);

% -------------------------------------------------------------------------
% Process each file
% -------------------------------------------------------------------------
for k = 1:numel(file_list)
    this_file  = file_list{k};
    fullpath   = fullfile(mon_dir,this_file);

    % Check if file exists
    if ~isfile(fullpath)
        fprintf(2,'\nFile not found: %s. Skipping.\n', this_file);
        continue;
    end

    % Check file size
    FileInfo   = dir(fullpath);
    FileSizeMB = FileInfo.bytes/(2^20);

    if FileSizeMB < min_file_size_mb
        % Just warn, do not do beep (per user request)
        fprintf(2,'\nFile %s too small (%.3f MB). Skipping.\n', this_file, FileSizeMB);
        continue;
    end

    % Extract the numeric portion from the filename (like d123 => filenum=123)
    [~, fname] = fileparts(fullpath);  % e.g. "d123"
    % e.g. find trailing digits
    numStr     = regexp(fname, '\d+$','match'); 
    if isempty(numStr)
        fprintf(2,'\nCannot parse filenum from %s. Skipping.\n', fname);
        continue;
    end
    filenum = str2double(numStr{1});
    baseName = fname(1:end-numel(numStr{1}));  % e.g. "d"

    % Run the existing conversion function
    % e.g.   dld_raw_to_txy_counts(<pathTo_d>, startFileNum, endFileNum)
    [counts, max_time] = dld_raw_to_txy_counts(fullfile(mon_dir, baseName), filenum, filenum);

    % Check rate (if you want to display a warning)
    avg_rate = counts/max_time;
    if avg_rate < min_counts_hz
        fprintf(2,'[WARNING] Low count rate in %s: counts=%d, avg=%.3f Hz\n', ...
                     this_file, counts, avg_rate);
    end

    % Log info
    fprintf('Converted %s => counts=%d (avg=%.2f Hz)\n', ...
                    this_file, counts, avg_rate);

    % Update rolling buffers only if we are plotting
    if do_plots
        count_circ_buffer = circshift(count_circ_buffer, -1);
        count_circ_buffer(end) = counts;
        trend_circ_buffer = circshift(trend_circ_buffer, -1);
        trend_circ_buffer(end) = counts;

        % Update plot
        refreshdata(hplot_trend,'caller');
        drawnow;

        % Save the figure
        saveas(gcf, fullfile(anal_out_dir, 'number_history.png'));
    end
end

fprintf('\nAll requested files have been processed.\n');

end
