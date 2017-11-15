% this will automaticaly monitor a directory and any files that match the 
% formating of thed tdc output files will convert them into txy format.
% The motivation is to somewhat front load the computation so that at the back end
% (analysis) it wont take as long. Further the DLD front pannel can directly
% acess these txy files to speed up looking at the data. 
%the code finds new or modified files (for free run) and then converts them
%after checking that the modification date is 1s in the past, or will wait
%till that is the case. This prevents converting a partial file.
%the program can also gracefully handle files being deleted

%TO BE IMPRVOVED
%strange runtime issue if the program waits to read a new file
%on converting it it realizes that the last modification date is after what
%triggered it originaly, to fix this i tried mod date once
%done waiting but still get the bug. Further investigation will look at how
%the tdc program writes the data as it may buffer then write at the end.
%If this is the case just wait the time out time since the creation or
%recent modification (that trigered the read).

%implement EMAIL notifications

%determine if datenum gives better resolution on the modification time of a
%file so that the wait_for_mod can be improved

%plot the counts of the last 300 conversions
 


%START USER VARIABLES
%watching_dir='D:\Public Data\Big Data\AutoConvert\testdir';
watching_dir='C:\Users\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output';
%watching_dir='S:\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output';
%Low_Count_Size=0.5;%min size in MB
Low_Count_Size=0.0;
wait_for_mod=2; %how many seconds in the past the modification date must be before proceding
%must be greater than 2 as mod time is only recorded to seconds

first_beep=0;
second_beep=1;

%END USER VAIRABLES

loop_num=1;
pause on
dir_init_content = dir(watching_dir);
initial_file_names = {dir_init_content.name};
initial_file_dates={dir_init_content.date};
initial_filenames_dates=[ initial_file_names ; initial_file_dates ]';
%cut . and .. from the listings
initial_filenames_dates=initial_filenames_dates(3:end,:);
initial_file_names=initial_file_names(3:end);
fprintf('\nMonitoring %s ', watching_dir);
    
while true
    dir_init_content = dir(watching_dir);
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
          FID=fopen(fullfile(watching_dir,new_files{k}),'r');
          FirstLine=fgetl(FID);
          SecondLine=fgetl(FID);
          fclose(FID);
          %check that the line lengths are right with 1 comma
          pass_line_test(k)=FirstLine(1)=='5' && size(SecondLine,2)<=15 ...
          && size(FirstLine,2)<=15 && sum(SecondLine==',')==1 && sum(FirstLine==',')==1;
        end
        if sum(pass_line_test)>0  
            new_files=new_files(logical(pass_line_test));
        else
             new_files=[];
        end
    end
      
    if ~isempty(new_files)
        %play a sound
        if first_beep
            fs = 16000;
            t = 0:(1/fs):0.02;
            f = 2000;
            a = 0.2;
            y = a*sin(2*pi*f*t);
            sound(y, fs);
        end
         
        % deal with the new files
        %meddage with number of new files found
        fprintf('\n(%d) new files detected \n',numel(new_files));
        for k=1:numel(new_files)
            fprintf('waiting to convert %s ...', new_files{k});

            %here i check if the modification date is more than 1 second
            %old, this relies on this computers clock being close to the TDC
            %computer (or running on the TDC computer)
            while is_early(watching_dir,new_files{k},wait_for_mod)
                fprintf('\b\b\b')
                pause(0.05*wait_for_mod)
                fprintf('.')
                pause(0.05*wait_for_mod)
                fprintf('.')
                pause(0.05*wait_for_mod)
                fprintf('.')
                pause(0.05*wait_for_mod)
            end
            
            FileInfo=dir(fullfile(watching_dir,new_files{k}));
            FileSize=FileInfo.bytes;
            FileSize=FileSize/(2^20);
            
            
            %I read the file size, if it is too small then i will not update
            if FileSize>Low_Count_Size
                
                if k==1 && second_beep
                    fs = 16000;
                    t = 0:(1/fs):0.02;
                    f = 1450;
                    a = 0.2;
                    y = a*sin(2*pi*f*t);
                    sound(y, fs);
                end
                %first reformat the string to have the path and the file number
                filename=new_files(k);
                filename=fullfile(watching_dir,new_files{k});%combine C:/dir/d123.txt
                filename=filename(1:end-4); %C:/dir/d123
                numpart=filename(end-5:end);  %/d123 so that can handle up to 99999
                numpart=regexp(numpart,'\d*','Match'); %give number component %/d123
                numpart=numpart{end}; %last number part in case of run1_123 which will return {1},{123} 
                filename=filename(1:end-size(numpart,2)); %remove numbers %C:/dir/d
                filenum=str2num(numpart); %convert to int
                
                counts=dld_raw_to_txy_counts(filename,filenum,filenum);
                fprintf(' Converted \n');
                fprintf('%0.0f counts\n',counts);
                
                %here is where i need to update filenames_dates for the
                %file i just processed
                
                %find new_files(k) in filenames_dates  then update the 2nd
                %col to FileDateDay
                mask=cellfun(@(x) isequal(x,new_files{k}), initial_filenames_dates(:,1));
                %refresh the file info
                FileInfo=dir(fullfile(watching_dir,new_files{k}));
                %write to the date
                initial_filenames_dates(mask,2)={FileInfo.date};
                
                %FileDateDay=FileInfo.datenum;%the file mod date is returned in seconds
                %cellfun(@(x) isequal(x,new_files{k}), filenames_dates(:,1))
                
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
        
        fprintf('Monitoring %s ', watching_dir);
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
    

