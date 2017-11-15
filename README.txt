AutoConvert
--------------------------------------------------------------------------------
 this will automaticaly monitor a directory and any files that match the 
formating of thed tdc output files will convert them into txy format.
The motivation is to somewhat front load the computation so that at the back end
 (analysis) it wont take as long. Further the DLD front pannel can directly
acess these txy files to speed up looking at the data. 
the code finds new or modified files (for free run) and then converts them
after checking that the modification date is 1s in the past, or will wait
till that is the case. This prevents converting a partial file.
the program can also gracefully handle files being deleted

TO BE IMPRVOVED
no known issues
 