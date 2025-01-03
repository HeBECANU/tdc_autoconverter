% WARNING: this code is 100% ChatGPT o1 generated.
% for how this code work, see the conversation archive below:
% https://chatgpt.com/share/67773c78-6ea4-8006-a362-337b153c0aea
%

function tdc_convert_filelist(file_list, mon_dir, min_file_size_mb, min_counts_hz, mov_mean_len)
    % tdc_convert_filelist
    %   Convert a *specific* list of files in mon_dir without waiting for new/modified files.
    %
    %   file_list : cell array of filenames (strings), e.g. {'d123.txt','d124.txt',...}
    %   mon_dir   : directory containing TDC text files
    %   ... other optional parameters as used in tdc_auto_convert ...

    % ---------------------------------------------------------------------
    % For safety, replicate any variables or initializations from tdc_auto_convert
    % that are needed below. E.g. sounds, figure initialization, etc.
    % Alternatively, just rely on each step inside tdc_auto_convert if you factor it well.
    % ---------------------------------------------------------------------

    % Example: load up the sounds used in the main code
    happy_sound=[];
    happy_sound.fs=16000;
    dur=0.03;
    t = linspace(0,dur,dur*happy_sound.fs);
    f = 1450;
    happy_sound.wf = 0.5*gausswin(size(t,2),3)'.*sin(2*pi*f*t);
    
    % Similarly load sad_sound, etc. if you want the beep logic.

    % Make sure output folders exist
    if (exist(fullfile(mon_dir,'out'),'dir') == 0)
        mkdir(fullfile(mon_dir,'out'));
    end
    anal_out_dir = fullfile(mon_dir,'out','monitor');
    if (exist(anal_out_dir, 'dir') == 0)
        mkdir(anal_out_dir);
    end

    % Initialize any trending or buffer logic (if you still want to track counts)
    mov_mean_len   = 30;
    lenLongTrendPlot=500;
    count_circ_buffer=NaN(mov_mean_len,1);
    trend_circ_buffer=NaN(lenLongTrendPlot,1);

    % Create figure for the trend if desired
    figure(1); clf;
    h=gca;
    hplot_trend=plot(trend_circ_buffer,'YDataSource','trend_circ_buffer',...
        'Color','b','LineStyle','--','Marker','d','LineWidth',2);
    title('Total hit-count trend');
    ylabel('Tot counts');
    set(gcf, 'Color', [1,1,1]);
    grid on; grid minor;   % styling

    % ---------------------------------------------------------------------
    % Now process the explicit file_list
    % ---------------------------------------------------------------------
    for k = 1:numel(file_list)
        this_file = file_list{k};
        fullpath  = fullfile(mon_dir,this_file);

        % Check file size
        if exist(fullpath,'file')
            FileInfo = dir(fullpath);
            FileSizeMB = FileInfo.bytes/(2^20);
            if FileSizeMB <= min_file_size_mb
                fprintf(2,'\nFile %s too small (%.2f MB), skipping.\n', this_file, FileSizeMB);
                % Optionally play sad sounds if you want
                % sound(sad_sound(1).wf, sad_sound(1).fs);
                continue;  % skip to next file
            end

            % If the file passes your basic checks, parse out the number from the filename
            % e.g. your existing logic in tdc_auto_convert:
            %   filename = 'C:\path\to\d123.txt'
            %   => root name: 'C:\path\to\d',  filenum=123
            [folderpart,fname] = fileparts(fullpath);  % e.g. fname='d123'
            % Extract the trailing digits
            numStr  = regexp(fname,'\d+$','match'); 
            if isempty(numStr)
                fprintf(2,'\nCannot extract filenum from %s\n', fname);
                continue;
            end
            filenum = str2double(numStr{1});
            baseName= fname(1:end-numel(numStr{1}));  % e.g. 'd'

            % Now call the same function you used: e.g.
            % [counts, max_time] = dld_raw_to_txy_counts('C:\path\to\d', 123, 123);
            [counts, max_time] = dld_raw_to_txy_counts(fullfile(folderpart, baseName), filenum, filenum);

            % If you want to do the beep logic
            % sound(happy_sound.wf,happy_sound.fs);

            % If you want the counts-based logic
            avg_rate = counts/max_time;
            fprintf('Converted %s => counts: %d, avg rate: %.2f Hz\n', ...
                       this_file, counts, avg_rate);

            % Update your circular buffers
            count_circ_buffer = circshift(count_circ_buffer,-1);
            count_circ_buffer(end)   = counts;
            trend_circ_buffer = circshift(trend_circ_buffer,-1);
            trend_circ_buffer(end)   = counts;

            % Refresh the plot (if desired)
            refreshdata(hplot_trend,'caller');
            drawnow;
            saveas(gcf, fullfile(anal_out_dir,'number_history.png'));

        else
            fprintf(2,'\nFile %s not found, skipping.\n', this_file);
        end
    end

    fprintf('\nAll requested files processed.\n');
end
