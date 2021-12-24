@echo "Clean up Quartus files"

@rmdir /s /q db 2>NUL >NUL
@rmdir /s /q incremental_db 2>NUL >NUL
@rmdir /s /q output_files 2>NUL >NUL
@rmdir /s /q greybox_tmp 2>NUL >NUL

pause

