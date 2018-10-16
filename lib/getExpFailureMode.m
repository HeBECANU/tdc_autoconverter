function errout = getExpFailureMode(txy,ferr_log)
%   Determines from reconstructed TXY data (for global rotation) if there was a fault in the
%   experiment, and returns the type.

% configs
Nmin=150;       % minimum number in region to pass
% ferr_log='Y:\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\global_rotation_constB\utility\tdc_autoconverter_20180428\ferr_log.txt';


% TOF limits to define number counting region
t1_lim=[0.39,0.4];
t2_lim=[0.4,0.43];

N1=sum((txy(:,1)>t1_lim(1))&(txy(:,1)<t1_lim(2)));
N2=sum((txy(:,1)>t2_lim(1))&(txy(:,1)<t2_lim(2)));
Ntot=N1+N2;


%%% error decision
errout=0;       % initialise with no error

if Ntot < Nmin
    % there are no atoms
    warning('EXP ERROR: no atoms detected. Check seed-laser and HV discharge source.');
    errout=1;
elseif N1>Nmin && N2<Nmin
    % there are no Raman scattered atoms
    warning('EXP ERROR: no Raman scattered atoms. Check the Raman laser.');
    errout=2;
else
    % everything seems OK
    % errout is 0
end
    
% broadcast experiment status
dlmwrite(ferr_log,errout);


%%% alarm
if errout > 0
    % some sort of fault!
%     [y,Fs]=audioread('killbill_siren.wav');
%     sound(y,Fs);
else
    % everything's OK
        % so don't do anything...
%     load handel.mat
%     sound(y,Fs);
end


end