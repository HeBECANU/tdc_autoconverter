TDC AutoConverter
--------------------------------------------------------------------------------

This is a fork of `AutoConvert v2` - a super useful tool for He\* BEC lab at ANU.

## Blurb (original)

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
 
## Improvements
- It's properly version controlled on git
- [ ] Simple moving average of reconstructed hit counts would be beneficial to user 
- [ ] package into a function

``` matlab
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
```
