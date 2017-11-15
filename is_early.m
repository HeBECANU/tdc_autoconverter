function[out]= is_early(watching_dir,new_file,wait_for_mod)
%this function simply checks that the modification date of a file is
%wait_for_mod seconds in the past
    file_pointer=dir(fullfile(watching_dir,new_file));
    out=addtodate(datenum(file_pointer.date),wait_for_mod,'second')>now;
end