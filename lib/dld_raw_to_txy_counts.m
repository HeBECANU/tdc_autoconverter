function[counts,max_time_all] = dld_raw_to_txy_counts(filename_raw,startfile,end_file)
%%% Use this to convert raw files from DLD to txy format
%%% which is used by C++ program such as
%%% g2_calc_norm_across_files_spatial_dy.exe to compute g2
%%% there is a 1:1 correspondance between input files and 
%%% output files with '_txy_forc'

% TO DO
% [ ] documentation into header template
% [ ] usage example
max_time_all=-inf;
for i=startfile:end_file
    file_no = num2str(i);
    filename_read = [filename_raw,file_no];
    [hits_sorted] = dld_read_5channels_reconst_multi_imp(filename_read,1,0,1,0);
    counts=size(hits_sorted,1);
    tlast=hits_sorted(end,1);
    if max_time_all<tlast
        max_time_all=tlast;
    end
    filename_write = [filename_raw,'_txy_forc',file_no,'.txt'];
    dlmwrite(filename_write,hits_sorted,'precision',8);

end

end
