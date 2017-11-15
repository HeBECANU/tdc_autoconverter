disp(initial_filenames_dates)
disp(filenames_dates)

if ~isequal(size(initial_filenames_dates),size(filenames_dates))
    fprintf(2,'error file array size does not agree\n')
end

if isequal(initial_filenames_dates(:,1),filenames_dates(:,1))
    fprintf(2,'file names do not agree perhaps the order has been mixed up\n')
end

modified=datenum(initial_filenames_dates(:,2))<datenum(filenames_dates(:,2));

mod_filenames=filenames_dates(modified,1)

