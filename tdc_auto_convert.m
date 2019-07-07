function tdc_auto_convert(mon_dir,min_file_size_mb,min_counts_hz,mov_mean_len)
%
% AutoConvert (mon_dir,min_file_size_mb,mov_mean_len)
%
% Continuously monitors the TDC output directory and processes incoming raw data into the TXY reconstructed format in real-time.
% The motivation is to somewhat front load the computation so that at the back end (analysis) TXY data is ready to be directly loadable. 
% Further the DLD front pannel can directly access these TXY files to speed up user monitoring of the experiment in real-time. 
%
% New or modified files (for free run) are detected and converted after checking that the modification date is 1s in the past, or will wait till that is the case. This prevents converting a partial file.
% The program can also gracefully handle files being deleted
% 
%Contributors
%Bryce Henson (bryce.henson@live.com), David Shin
%To Do
%   [x] add check that last line is empty to signal that file is done writing
%   [x] sad sound if file too small
%   [ ] save picture of atom number history
%   [ ] verbose levels
%   - documentation
%   - sad sound if not enoguh atoms
%   - add in in find_data_files
%   - fix email alert

% BEGIN USER VAR-------------------------------------------------
lenLongTrendPlot=500;
wait_for_mod=4;         %how many seconds in the past the modification date must be before proceding
%must be greater than 2 as mod time is only recorded to seconds
first_beep=0;
second_beep=1;
mon_dir_default='\\amplpc29\Users\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output';
% END USER VAR-----------------------------------------------------------


%add all subfolders to the path
this_folder = fileparts(which(mfilename));
% Add that folder plus all subfolders to the path.
addpath(genpath(this_folder));

% parse inputs
if ~exist('mon_dir','var')
    warning('mon_dir is undefined. Setting to default: %s',mon_dir_default);
    mon_dir=mon_dir_default;
elseif isempty(mon_dir)
    warning('mon_dir is undefined. Setting to default: %s',mon_dir_default);
    mon_dir=mon_dir_default;
end
if ~exist('min_file_size_mb','var')
    warning('min_file_size_mb is undefined. Setting to default: 0 MB');
    min_file_size_mb=0;     %min size in MB
end
if ~exist('mov_mean_len','var')
    mov_mean_len=30;
    warning('mov_mean_len is undefined. Setting to default: %u',mov_mean_len);
end
if ~exist('min_counts_hz','var')
    min_counts_hz=700;
    warning('min_counts_hz is undefined. Setting to default: %.1f',min_counts_hz);
end
%make a 
if (exist(fullfile(mon_dir,'out'),'dir') == 0), mkdir(fullfile(mon_dir,'out')); end
anal_out_dir=[fullfile(mon_dir,'out','monitor'),filesep];
if (exist(anal_out_dir, 'dir') == 0), mkdir(anal_out_dir); end

%set up the output sounds
happy_sound=[];
happy_sound.fs=16000;
dur=0.03;
t = linspace(0,dur,dur*happy_sound.fs);
f = 1450;
happy_sound.wf = 0.5*gausswin(size(t,2),3)'.*sin(2*pi*f*t);
%sound(happy_sound.wf, happy_sound.fs)      
clear('dur','f','t')
sad_sound=[];
[sad_sound(1).wf, sad_sound(1).fs] = audioread(fullfile('.','lib','sounds','Upset_TwoTone.mp3'));
[sad_sound(2).wf, sad_sound(2).fs] = audioread(fullfile('.','lib','sounds','Short_Raspberry.mp3'));
start_sound=[];
[start_sound.wf, start_sound.fs] = audioread(fullfile('.','lib','sounds','Happy_ThreeChirp.mp3'));
start_sound.wf=start_sound.wf*0.5;

%initalize
loop_num=1;
pause on
dir_init_content = dir(mon_dir);
initial_file_names = {dir_init_content.name};
initial_file_dates={dir_init_content.date};
initial_filenames_dates=[ initial_file_names ; initial_file_dates ]';
%cut . and .. from the listings
initial_filenames_dates=initial_filenames_dates(3:end,:);
initial_file_names=initial_file_names(3:end);

count_circ_buffer=NaN(mov_mean_len,1);     % initialise count buffer from latest N shots
% long term count trend graph
trend_circ_buffer=NaN(lenLongTrendPlot,1);
hfig_trend=figure(1);
h=gca;
hplot_trend=plot(trend_circ_buffer,'YDataSource','trend_circ_buffer',...
    'Color','b','LineStyle','--','Marker','d','LineWidth',2);
title('Total hit-count trend');
ylabel('Tot counts');
set(gcf, 'Color', [1,1,1]);
grid on    % turn on major grid lines
grid minor % turn on minor grid lines
% Set limits and grid spacing separately for the two directions:
% Must set major grid line properties for both directions simultaneously:
h.GridLineStyle='-'; % the default is some dotted pattern, I prefer solid
h.GridAlpha=1;  % the default is partially transparent
h.GridColor=[0,0,0]; % here's the color for the major grid lines
% Idem for minor grid line properties:
h.MinorGridLineStyle='-';
h.MinorGridAlpha=0.1;
h.MinorGridColor=[0,0,0]; % here's the color for the minor grid lines

%start sound
sound(start_sound.wf, start_sound.fs)
clear('start_sound')

fprintf('\nMonitoring %s \n ', mon_dir);

while true    
    %%% monitor directory
    dir_init_content = dir(mon_dir);
    file_names = {dir_init_content.name};
    file_dates=  {dir_init_content.date};
    filenames_dates=[ file_names ; file_dates ]';
    %cut . and .. from the listings
    file_names=file_names(3:end);
    filenames_dates=filenames_dates(3:end,:);
    new_files = setdiff(file_names,initial_file_names);
    deleted_files=setdiff(initial_file_names,file_names);

    %remove new files from the filenames_dates array
    %dont need to do this for inital as should be the same
    filenames_dates_newcut=filenames_dates(~ismember(file_names,new_files),:);
    
    %cut deleted files from the initial array
    non_deleted_mask=~ismember(initial_filenames_dates(:,1),deleted_files);
    initial_filenames_dates=initial_filenames_dates(non_deleted_mask,:);

    if ~isequal(size(initial_filenames_dates),size(filenames_dates_newcut))
        fprintf(2,'error file array size does not agree\n')
    end
    if ~isequal(initial_filenames_dates(:,1),filenames_dates_newcut(:,1))
        fprintf(2,'file names do not agree perhaps the order has been mixed up\n')
        disp(initial_filenames_dates)
        disp(filenames_dates_newcut)
    end
    %catch the empty case
    if ~(size(initial_filenames_dates,1)==0 || size(filenames_dates,1)==0)
      modified=datenum(initial_filenames_dates(:,2))<datenum(filenames_dates_newcut(:,2));
    else
        modified=[];
    end
    
    %add the moded file names to the new_files
    new_files=[new_files, filenames_dates(modified,1)'];

    %chop off txy data,LOG_parameters.txt and keep txt files
    new_files=new_files(cellfun(@(x) isempty(findstr('_txy_forc',x)),new_files));
    new_files=new_files(cellfun(@(x) isempty(findstr('LOG_parameters',x)),new_files));
    new_files=new_files(cellfun(@(x) ~isempty(findstr('.txt',x)),new_files));

    initial_file_names = file_names;
    initial_filenames_dates=filenames_dates;
    
    if ~isempty(new_files)
        %now we check if the first few lines in the file are the right format
        %prealocate the pass list
        %pass_line_test=[];
        pass_line_test=zeros(numel(new_files),1);
        pause(0.05) %this makes sure that the first few lines have been written
        for k=1:numel(new_files)   
          FID=fopen(fullfile(mon_dir,new_files{k}),'r');
          FirstLine=fgetl(FID);
          SecondLine=fgetl(FID);
          fclose(FID);
          %check that the line lengths are right with 1 comma
          if  ~isequal(FirstLine,[]) && ~isequal(SecondLine,[])
            pass_line_test(k)=FirstLine(1)=='5' && size(SecondLine,2)<=15 ...
            && size(FirstLine,2)<=15 && sum(SecondLine==',')==1 && sum(FirstLine==',')==1;
          end
        end
        if sum(pass_line_test)>0  
            new_files=new_files(logical(pass_line_test));
        else
             new_files=[];
        end
    end
      
    if ~isempty(new_files)
        fprintf('\n(%d) new files detected \n',numel(new_files));
        for k=1:numel(new_files)
            fprintf('waiting to convert %s ...', new_files{k});
            %here i check if the modification date is more than 1 second
            %old, this relies on this computers clock being close to the TDC
            %computer (or running on the TDC computer)
            while is_early(mon_dir,new_files{k},wait_for_mod)
                fprintf('\b\b\b')
                pause(0.05*wait_for_mod)
                fprintf('.')
                pause(0.05*wait_for_mod)
                fprintf('.')
                pause(0.05*wait_for_mod)
                fprintf('.')
                pause(0.05*wait_for_mod)
            end
            
            FileInfo=dir(fullfile(mon_dir,new_files{k}));
            FileSize=FileInfo.bytes;
            FileSize=FileSize/(2^20);
            
            
            %read the file size, if it is too small then will not update
            if FileSize>min_file_size_mb
                
                if k==1 && second_beep
                   sound(happy_sound.wf, happy_sound.fs);
                end
                %first reformat the string to have the path and the file number
                filename=new_files(k);
                filename=fullfile(mon_dir,new_files{k});%combine C:/dir/d123.txt
                filename=filename(1:end-4); %C:/dir/d123
                numpart=filename(end-5:end);  %/d123 so that can handle up to 99999
                numpart=regexp(numpart,'\d*','Match'); %give number component %/d123
                numpart=numpart{end}; %last number part in case of run1_123 which will return {1},{123} 
                filename=filename(1:end-size(numpart,2)); %remove numbers %C:/dir/d
                filenum=str2num(numpart); %convert to int

                
                [counts,max_time]=dld_raw_to_txy_counts(filename,filenum,filenum);
                fprintf(' done\n');
                
                avg_rate=counts/max_time;
                if avg_rate<min_counts_hz
                    fprintf(2,'!!!!!!!!!!!!!!!!!!!LOW COUNTS!!!!!!!!!!!!!!!!!!\n');
                    fprintf(2,'Total Counts %u avg rate in file %.3f \n',counts,avg_rate);
                    sound(sad_sound(1).wf, sad_sound(1).fs);
                    pause(size(sad_sound(1).wf,1)/sad_sound(1).fs)
                    sound(sad_sound(2).wf, sad_sound(2).fs);
                end
                % update count buffers
                count_circ_buffer=circshift(count_circ_buffer,-1,1);
                count_circ_buffer(end)=counts;
                trend_circ_buffer=circshift(trend_circ_buffer,-1,1);
                trend_circ_buffer(end)=counts;
                % simple moving filter (diagnostic for drift and stability)
                mov_avg_counts=mean(count_circ_buffer,'omitnan');   
                mov_std_counts=std(count_circ_buffer,'omitnan');    
                % report smoothed number
                fprintf('counts %0.0f, SMA(%d) %0.0f, sd %0.0f\n',counts,mov_mean_len,mov_avg_counts,mov_std_counts); % %8.3g
                % refresh plot
                refreshdata(hplot_trend, 'caller')
                axis auto;
                drawnow;
                saveas(gcf,fullfile(anal_out_dir,'number_history.png'))
                %TODO: save plot to file
                
                
                %%% START
                % simple global rotation experiment health check up 
%                 this_txy=txy_importer(fullfile(mon_dir,'\d'),filenum);   % get TXY for this file
%                 ferr_log=fullfile(mon_dir,'ferr_log.txt');
%                 getExpFailureMode(this_txy,ferr_log);
                
                %%% END

                %update filenames_dates for the file just processed
                %find new_files(k) in filenames_dates  then update the 2nd col to FileDateDay
                mask=cellfun(@(x) isequal(x,new_files{k}), initial_filenames_dates(:,1));
                %refresh the file info
                FileInfo=dir(fullfile(mon_dir,new_files{k}));
                %write to the date
                initial_filenames_dates(mask,2)={FileInfo.date};
                
                %EMAIL STUFF
                %low_count_files=0;
                %high_count_files=high_count_files+1;
                %if high_count_files>5 && emailsent==1 && ~isempty(Email_add)
                %    emailsent=0; %hysterisis in the reset to prevent email spam
                %    fprintf(2,'Source Started Sending Email Alert\n')
                %    SendEmail(Email_add,'Source Started',...
                %    sprintf('The source has started up based on the file size for %d shots of the experiment. The time is %s. The scan is %4.1f %% complete.Projected ETA %s HH:MM finishing at %s \n',...
                %    high_count_files,datestr(now, 'dd mmm HH:MM'),100*(progress+repeats),datestr(ETA_Days,'HH:MM'),datestr(datenum(clock)+ETA_Days,'dd mmm HH:MM')));
                %end
            else
                sound(sad_sound(1).wf, sad_sound(1).fs);
                pause(size(sad_sound(1).wf,1)/sad_sound(1).fs)
                sound(sad_sound(2).wf, sad_sound(2).fs);
                
                
                %EMAIL STUFF
                %if it is too low then a red text message is displayed
                %if this happens enough then i send an email to myself
                %low_count_files=low_count_files+1;
                fprintf(2,'\n file is too small(%2.3f MiB) will not update.\n',FileSize)
                %if low_count_files>5 && emailsent==0 && ~isempty(Email_add)
                %    high_count_files=0;
                %    emailsent=1; %prevents spaming my inbox
                %    fprintf(2,'Sending Email Alert\n')
                %    ETA_Days=(1-progress)*(datenum(clock-start_time)/(progress+repeats));
                %    SendEmail(Email_add,'Source Dropout',...
    %                 sprintf('The source has dropped out based on the file size for %d shots of the experiment. The time is %s. The scan is %4.1f %% complete.Projected ETA %s HH:MM finishing at %s \n',...
    %                 low_count_files,datestr(now, 'dd mmm HH:MM'),100*(progress+repeats),datestr(ETA_Days,'HH:MM'),datestr(datenum(clock)+ETA_Days,'dd mmm HH:MM')));
    %             end
            end
        end
        
        %%% pretty output
        %fprintf('-----------------------------------------------------------\n');
        %fprintf('Monitoring %s \n', mon_dir);
        
        loop_num=1;
    else
        
        if mod(loop_num,4)==0
            pause(.2)
            fprintf('\b\b\b')
            loop_num=1;
        else
            pause(.1) %little wait animation
            fprintf('.')
            loop_num=loop_num+1;
        end
        
      end
end
    
end