function  data=txy_importer(filepath,filenum)
%this function imports txy files faster by using strongly a matched import
%single precision 3 digits
%simply pass the filepath and file number (as string)
% 31/10/16 DKS - filenum will accept integer and int string - error raised
%   for null output and non-int/str filenum

%% ERROR CHECK
% Check filenum variable type
if isa(filenum,'char')
    if isempty(str2double(filenum))
        data=[];
        warning(['filenum: ',filenum,' is not an integer string - returning null data']);
        return
    else
        filenum=str2double(filenum);
    end
elseif ~isa(filenum,'double')
    % error on data type
    data=[];
    warning(['filenum is not an int or int str - returning null data']);
    return
end

% Check filenum is an integer
if ~(filenum==floor(filenum))
    data=[];
    warning(['filenum: ',num2str(filenum),' is not an integer - returning null data']);
    return
end

%% LOAD DATA
fileID = fopen([filepath,'_txy_forc',num2str(filenum),'.txt'],'r');
data = textscan(fileID,'%f32%f32%f32',...%f32
    'Delimiter', ',', ...
    'MultipleDelimsAsOne',0,...
    'ReturnOnError', true,...
    'NumCharactersToSkip',0,... 
    'CollectOutput', true,...
    'EndOfLine','\n');
fclose(fileID);
data=data{1};

end
