function watchErrLog(path_err_log)
% watches the real-time health of experiment
%   error code disambiguation
%   0   OK
%   1   No atoms
%   2   No Raman scattered atoms

if ~exist('path_err_log','var')
    % set to the default path: dld_output/ferr_log.txt
    warning('path to error log is not set. Setting to default: \\AMPLPC29\Users\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\ferr_log.txt');
    path_err_log='\\AMPLPC29\Users\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\ferr_log.txt';
end


loop_delay=60;  % in seconds - don't make it too annoying (exp duty-cycle ~30s)

while true
    % read error code
    errcode=dlmread(path_err_log);
    
    % act
    if errcode>0
        % RING ALARM
        [y,Fs]=audioread('killbill_siren.wav');
        sound(y,Fs);
        
    else
        % everything's OK
        % so don't do anything...
		load handel.mat
		sound(y,Fs);
        
    end
    
    pause(loop_delay);
end

end