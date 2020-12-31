package CRISTA_GLOBALS;

sub validate_nuc_seq_length
{
    my $Seq_Name = shift;
    my $seq = shift;
    my $seq_length = shift;

    if ($seq !~ /[AGCTUagctu]+/)
    {
        return ("'$Seq_Name' contains invalid characters<br>Valid characters are ACGTU.");
    }
    elsif (length($seq) != $seq_length)
    {
        return ("Seq: '$Seq_Name' is not of length '$seq_length'<br>");
    }
    return ("OK");
}


sub remove_spaces_from_string
{
    my $str = shift;
    (my $str_res = $str) =~ s/\s//g;
    return ($str_res);
}


sub create_new_dir {
    while (-e $main::VARS{WorkingDir}) # while file exists
    {
        $main::VARS{RUN_NUMBER} = $^T; # get new number
        $main::VARS{WorkingDir} = $main::VARS{resultsDir}.$main::VARS{RUN_NUMBER}."/";
    }
    mkdir $main::VARS{WorkingDir};
    chmod 0755, $main::VARS{WorkingDir};

    open LOG, ">>$main::VARS{OutLogFile}";
    print LOG "\ncreate_new_dir $main::VARS{WorkingDir}\n";
    close LOG;



    ###### check if the new directory exists. If it doesn't exist, exit the script!
    unless (-d $main::VARS{WorkingDir}) {
        open OUTPUT, ">>$main::VARS{OutHtmlFile}";
		use IO::Handle;
		$main::VARS{OutHtmlFile}->flush();		#Added to solve issue on Power - output.php  
        print OUTPUT $main::VARS{SysErrorDef};
        print OUTPUT $main::VARS{ContactDef};
        close OUTPUT;
        open LOG, ">>$main::VARS{OutLogFile}";
        print LOG "\ncreate_new_dir: Couldn\'t create the directory $main::VARS{WorkingDir}\n";
        close LOG;
        my $err = "create_new_dir: Couldn\'t create the directory $main::VARS{WorkingDir}";
        &send_mail($err); # TO DO - exit_on_error
        &stop_reload;
        exit;
    }

    ###### changing permissions for whole new dir VERY IMPORTANT !!
    open LOG, ">>$main::VARS{OutLogFile}";
    print LOG "\ncreate_new_dir: Change the permissions of the directory $main::VARS{RUN_NUMBER}\n";
    close LOG;

    #	system 'echo "(chmod oug+wrx '.$main::VARS{WorkingDir}.';)" | /bin/tcsh';
    system ("chmod 0755 $main::VARS{WorkingDir}");
}

####################################################################################
###### Stops the reload of the output page
sub stop_reload {

    open LOG, ">>$main::VARS{OutLogFile}";
    print LOG "\nEnd time: ".BIOSEQUENCE_FUNCTIONS::printTime();
    close LOG;

    #sleep ($main::VARS{reload_interval});
	#sleep(30);
    open OUTPUT, "<$main::VARS{OutHtmlFile}";
    my @output = <OUTPUT>;
    close OUTPUT;

    open OUTPUT, ">$main::VARS{OutHtmlFile}";
    foreach my $line (@output) {

        unless ($line =~ /REFRESH/ or $line =~ /NO-CACHE/) {

            print OUTPUT $line;
        }
    }
    close OUTPUT;
    chmod 0600, $main::VARS{WorkingDir}."user_email.txt";
}


#######################################################################################
###### Start writing the output web page of CRISTA
sub start_output_html {

    #system 'echo "(touch '.$main::VARS{OutHtmlFile}.'; chmod oug+rxw '.$main::VARS{OutHtmlFile}.')" | /bin/tcsh';
	system ("chmod 0755 $main::VARS{OutHtmlFile}");
	unless (open OUTPUT, ">$main::VARS{OutHtmlFile}") {
        open LOG, ">>$main::VARS{OutLogFile}";
        print LOG "\nstart_output_html: Cannot open the output file $main::VARS{OutHtmlFile}\n";
        close LOG;
        exit;
    }
    
    open LOG, ">>$main::VARS{OutLogFile}";
    print LOG "start_output_html: Opening the file $main::VARS{OutHtmlFile}, and change the permissions of the WorkingDir\n";
    close LOG;

    open(FILE, '/bioseq/crista/CRISTA_online/results_html_template.html') or die "Can't read file 'filename' [$!]\n";
    my $html_template_str = "";
    my $line = "";
    while (<FILE>) {
        $line = $_;
        if (index($line, "{0}") != -1) {
            $line = $line =~ s/(\{0\})/$main::VARS{reload_interval}/r;
        }
        if (index($line, "{1}") != -1) {
            $line = $line =~ s/(\{1\})/$main::VARS{RUN_NUMBER}/r;
        }
        if (index($line, "{2}") != -1) {
            $line = $line =~ s/(\{2\})/$main::VARS{RUNNING_MODE}/r;
        }
        if (index($line, "{3}") != -1) {
            $line = $line =~ s/(\{3\})/$main::VARS{RUNNING_PARAMS_TEXT}/r;
        }
        $html_template_str .= $line
    }
    close (FILE);

    #my $STATUS_FILE=$main::VARS{WorkingDir}."QUEUE_STATUS";
    #my $TIME_PASSED=$main::VARS{WorkingDir}."TIME_PASSED";
    #open (QUEUE_STATUS,">$STATUS_FILE");
    #print QUEUE_STATUS "Queued";
    #close QUEUE_STATUS;

    #open (TIME_PASSED,">$TIME_PASSED");
    #print TIME_PASSED "00:00";
    #close TIME_PASSED;


    #<BODY bgcolor="#FFF5EE">
    #<H1 align=center>CRISTA Job Status Page - <font color='red'>RUNNING</font></h1>
    print OUTPUT <<EndOfHTML;
    $html_template_str
EndOfHTML

    close OUTPUT;
	
}

######################################################################################

###### UPLOAD file
sub upload_file ($$) {

    #my $full_path = $_[0]; #what the user provide us, which is the path + name before stripping.
    #my $file_full_name = $_[1]; 

    my $fileOnServer = $_[0];
    my $fileOnUserComputer = $_[1];

    open LOG, ">>$OutLogFile";
    print LOG "\n fileOnUserComputer before stripping = $fileOnUserComputer \n";
    close LOG;

    # strip the remote path and keep the filename
    $fileOnUserComputer =~ m/^.*(\\|\/)(.*)/;
    $ShortfileOnUserComputer = $2;

    open LOG, ">>$OutLogFile";
    print LOG "\n short fileOnUserComputer after stripping = $ShortfileOnUserComputer \n";
    close LOG;

    open LOG, ">>$OutLogFile";
    #print LOG "\n upload_file : FILE_NAME = $full_path \n";
    print LOG "\n upload_file : FILE_NAME = $fileOnServer \n"; #the argument is the name of the file on server to upload
    close LOG;

    system 'echo "(touch '.$fileOnServer.'; chmod oug+w '.$fileOnServer.')" | /bin/tcsh';

    ###### if the upload didn't work
    unless (open(UPLOADFILE, ">$fileOnServer")) {
        open OUTPUT, ">>$OutHtmlFile";
        print OUTPUT $SysErrorDef;
        print OUTPUT $ContactDef;
        close OUTPUT;

        open LOG, ">>$OutLogFile";
        print LOG "\nupload_file: Can\'t open the file $fileOnServer\n";
        close LOG;

        my $err = "SYSTEM ERROR\nupload_file: Can\'t open the file $fileOnUserComputer";
        &send_mail($err);
        &stop_reload;
        exit;
    }

    open LOG, ">>$OutLogFile";
    print LOG "\nupload_file: Upload the file $fileOnUserComputer and save it as $fileOnServer\n";
    close LOG;

    ###### this is the actual uploading.
    while (<$fileOnUserComputer>)  {
        print UPLOADFILE;
    }
    close UPLOADFILE;


    # verify that the size of the file is not zero
    if (-z $fileOnServer) {
        open OUTPUT, ">>$OutHtmlFile";
        print OUTPUT "\n<p>$ErrorDef<br><b>Cannot upload the file \'$fileOnUserComputer\', Please verify that the file exists and contains data.</b></p>\n";
        print OUTPUT $ContactDef;
        close OUTPUT;

        open LOG, ">>$OutLogFile";
        print LOG "\nupload_file: Cannot upload the file \'$fileOnUserComputer\'\n";
        close LOG;

        my $err2 = "upload_file: Cannot upload the file \'$fileOnUserComputer\'";
        &send_mail($err2);
        &stop_reload;
        exit;
    }

    system "cd $WorkingDir; chmod ogu+rx *";
}

####################################################################################
##### Update users log
sub Update_Users_Log
{
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $submission_time = $hour.':'.$min.':'.$sec;
    my $curr_time = $submission_time." $mday-".($mon + 1)."-".($year + 1900);

    my $user_ip = $ENV{'REMOTE_ADDR'};  # this is one of the variables that perl's %ENV gives us
    my $rns_log = GENERAL_CONSTANTS::CRISTA_LOG;
    open LIST, ">>".$rns_log;
    flock LIST, 2;
    print LIST $curr_time." ".$main::VARS{RUN_NUMBER}." ".$user_ip." ".$main::VARS{user_email}."\n";
    flock LIST, 8;
    close LIST;
}

##### Sends an automatic mail when there are errors
sub send_mail {

    my $message = shift;

    open LOG, ">>$main::VARS{OutLogFile}";
    print LOG "send_mail: message = $message\n";
    close LOG;

    GENERAL_CONSTANTS::send_mail("CRISTA", $main::VARS{user_email}, $main::VARS{RUN_NUMBER}, "error", "error", "",
        "ibis") if ($main::VARS{user_email} ne "");
    GENERAL_CONSTANTS::send_mail("CRISTA", $main::VARS{DEVELOPER_MAIL}, $main::VARS{RUN_NUMBER}, "error",
        $message."\nUser email: $main::VARS{user_email}", "", "ibis");

}

# HANDLE EXIT
sub exit_on_error{
    my $which_error = shift;
    my $error_msg = shift;

    my $error_definition = "<font size=+2 color='red'>ERROR! CRISTA session has been terminated:</font><br />\n";
    my $syserror = "<font size=+1 color='red'>A SYSTEM ERROR OCCURRED!</font><br />Plesae try to run CRISTA again in a few minutes.<br />We apologize forthe inconvenience.<br />\n";

    if ($which_error eq 'user_error') {
        open LOG, ">>$main::VARS{LogFile}";
        print LOG "\n\t EXIT on error:\n$error_msg\n";
        if (-e "$main::VARS{OutHtmlFile}") # OUTPUT IS OPEN
        {
            open (OUTPUT, ">>$main::VARS{OutHtmlFile}");
            print OUTPUT  $error_definition."$error_msg";
            close (OUTPUT);
        }
        else # OUTPUT WAS NOT CREATED
        {
            print "Content-type: text/html\n\n";
            print "<html>\n";
            print "<head>\n";
            print "<title>ERROR has occurred</title>\n";
            print "</head>\n";
            print "<body>\n";
            print $error_definition."$error_msg";
        }
        # print $error_msg to the screen
        close LOG;
    }
    elsif ($which_error eq 'sys_error') {
        send_administrator_mail_on_error ($error_msg);
        if (-e "$main::VARS{OutHtmlFile}") # OUTPUT IS OPEN
        {
            open LOG, ">>$main::VARS{OutLogFile}";
            print LOG "\n$error_msg\n";
            print OUTPUT $syserror;
        }
        else  # Output not open
        {
            print "Content-type: text/html\n\n";
            print "<html>\n";
            print "<head>\n";
            print "<title>ERROR has occurred</title>\n";
            print "</head>\n";
            print "<body>\n";
            print $syserror;
        }
        #print $error_msg to the log file
        close LOG;
    }
    close OUTPUT;

    if ($main::VARS{user_email})
    {
        send_mail_on_error();
    }
    update_output_that_run_failed();
    open LOG, ">>$OutLogFile";
    print LOG "\nExit Time: ".(BIOSEQUENCE_FUNCTIONS::printTime)."\n";
    close LOG;
    chmod 0755, $main::VARS{WorkingDir};
    exit;
}

########################################################################################
sub send_mail_on_error
{
    #	my $user_email=shift;    # GLOBAL VARS
    #	my $run_url=shift;       # GLOBAL VARS
    #	my $output_page=shift;   # GLOBAL VARS
    #	my $run_number=shift;    # GLOBAL VARS
    my $email_subject;
    my $HttpPath = $main::VARS{run_url};
    $email_subject = "'Your CRISTA run $main::VARS{RUN_NUMBER} FAILED'";
    my $email_message = "'Hello,\\n\\nUnfortunately your CRISTA run (number ".$main::VARS{RUN_NUMBER}.") has failed";
    $email_message = $email_message."\nJob title: $main::VARS{JOB_TITLE}\n" if ($main::VARS{JOB_TITLE} ne "");
    $email_message = $email_message."\\nPlease have a look at ".$HttpPath." for further details\\n\\nSorry for the inconvenience\\nCRISTA Team'";
    my $msg = "ssh bioseq\@jekyl \"cd $main::VARS{send_email_dir}; ".'./sendEmail.pl -f \'TAU BioSequence <bioSequence@tauex.tau.ac.il>\' -t \''.$main::VARS{user_email}.'\' -u '.$email_subject.' -xu '.$main::VARS{userName}.' -xp '.$main::VARS{userPass}.' -s '.$main::VARS{smtp_server}.' -m '.$email_message.'"';
    #if ($attach ne ''){$msg.=" -a $attach"; print LOG "sending $msg\n";}
    open LOG, ">>$main::VARS{OutLogFile}";
    print LOG "MESSAGE:$email_message\nCOMMAND:$msg\n";
    chdir $main::VARS{send_email_dir};
    my $email_system_return = `$msg`;
    unless ($email_system_return =~ /successfully/) {
        print LOG "send_mail: The message was not sent successfully. system returned: $email_system_return\n";
    }
    close LOG;
}

####################################################################################
sub send_administrator_mail_on_error
{
    my $message = shift;
    my $email_subject;
    $email_subject = "'System ERROR has occurred on CRISTA: $main::VARS{run_url}'";
    my $email_message = "'Hello,\\n\\nUnfortunately a system System ERROR has occurred on CRISTA: $main::VARS{run_url}.\\nERROR: $message.'";
    my $Admin_Email = GENERAL_CONSTANTS::ADMIN_EMAIL;
    my $msg = "ssh bioseq\@jekyl \"cd $main::VARS{send_email_dir}; ".'./sendEmail.pl -f \'bioSequence@tauex.tau.ac.il\' -t \''."bioSequence\@tauex.tau.ac.il".'\' -u '.$email_subject.' -xu '.$main::VARS{userName}.' -xp '.$main::VARS{userPass}.' -s '.$main::VARS{smtp_server}.' -m '.$email_message.'"';
    chdir $main::VARS{send_email_dir};
    my $email_system_return = `$msg`;

}
sub update_output_that_run_failed
{
    close OUTPUT;
    # finish the output page
    #    sleep 10;
    open OUTPUT, "$main::VARS{OutHtmlFile}";
    my @output = <OUTPUT>;
    close OUTPUT;
    # remove the refresh commands from the output page
    open OUTPUT, ">$main::VARS{OutHtmlFile}";
    foreach my $line (@output) {
        if (($line =~ /TTP-EQUIV="REFRESH"/) or ($line =~ /CONTENT="NO-CACHE"/))
        {
            next;
        }
        elsif ($line =~ /(.*)RUNNING(.*)/)
        {
            print OUTPUT $1."FAILED".$2;
        }
        else {
            print OUTPUT $line;
        }
    }
    print OUTPUT "<h4 class=footer align=\"center\">Questions and comments are welcome! Please <span class=\"admin_link\"><a href=\"mailto:bioSequence\@tauex.tau.ac.il\?subject=CRISTA\%20Run\%20Number\%20$main::VARS{RUN_NUMBER}\">contact us</a></span></h4>";
    print OUTPUT "</body>\n";
    print OUTPUT "</html>\n";
    close OUTPUT;
}


sub send_to_queue {
    my $crista_comm = shift;
	    
    open LOG, ">>$main::VARS{OutLogFile}";
    print LOG "\nrun crista: running $crista_comm\n";

    my $qsub_script = "qsub.sh"; # script to run in the queue


    open (QSUB_SH, ">$main::VARS{WorkingDir}".$qsub_script);

    ### FOR LECS
    ####################
    #print QSUB_SH '#!/bin/tcsh', "\n";
    #print QSUB_SH '#$ -N ', 'CRISTA_', "$main::VARS{RUN_NUMBER}\n";
    #print QSUB_SH '#$ -S /bin/tcsh', "\n";
    #print QSUB_SH '#$ -cwd', "\n";
    #print QSUB_SH '#$ -e ', $main::VARS{WorkingDir}, '/$JOB_NAME.$JOB_ID.ER', "\n";
    #print QSUB_SH '#$ -o ', $main::VARS{WorkingDir}, '/$JOB_NAME.$JOB_ID.OU', "\n";
    
	### FOR POWER
    ####################
    print QSUB_SH '#!/bin/bash', "\n";
    print QSUB_SH '#PBS -N ', 'CRISTA_', "$main::VARS{RUN_NUMBER}\n";
    print QSUB_SH '#PBS -r y', "\n";
    print QSUB_SH '#PBS -q lifesciweb', "\n";
    print QSUB_SH '#PBS -v PBS_O_SHELL=bash,PBS_ENVIRONMENT=PBS_BATCH', "\n";
    print QSUB_SH '#PBS -e ', $main::VARS{WorkingDir}, '/', "\n";
    print QSUB_SH '#PBS -o ', $main::VARS{WorkingDir}, '/', "\n";

    my $cmd = "cd $main::VARS{WorkingDir}\nmodule load python/python-anaconda3.6.5\nmodule load bwa/bwa-0.7.17\nmodule load samtools/samtools-1.6\npython $crista_comm";
    print QSUB_SH "$cmd\n";
	#my $cmd = "cd $main::VARS{WorkingDir}\nmodule load python/anaconda3-4.0.0\npython $crista_comm";
    #my $cmd = "cd $main::VARS{WorkingDir}\nmodule load python/python-3.3.0\npython $crista_comm";
    
    close QSUB_SH;
    chmod 0755, "$main::VARS{WorkingDir}/$qsub_script";
    chmod 0600, "$main::VARS{WorkingDir}JOB_TITLE" if (-e "$main::VARS{WorkingDir}JOB_TITLE");
    my $qsub_job_no = "NONE";
    
#	my $q_cmd = 'ssh bioseq@lecs2 qsub '."-l bioseq $main::VARS{WorkingDir}/$qsub_script";
#   my $q_cmd = 'ssh bioseq@jekyl qsub '."-l 12tree $main::VARS{WorkingDir}/$qsub_script";
    my $q_cmd = 'ssh bioseq@powerlogin qsub '."$main::VARS{WorkingDir}/$qsub_script";
    
	print LOG "\nsubmit_job_to_Q :\n$q_cmd\n";
    my $ans = `$q_cmd`;
    if ($ans =~ /(\d+)/)
    {
        $qsub_job_no = $1;
    }
    print LOG "submit_job_to_Q : job number in the queue: $qsub_job_no\n";
    open QSTAT, ">$main::VARS{WorkingDir}/QSUB_NO";
    print QSTAT $qsub_job_no;
    close QSTAT;
	sleep(30);
    # Add to the submmited jobs list
    BIOSEQUENCE_FUNCTIONS::update_submitted_list("CRISTA", "CRISTA_".$main::VARS{RUN_NUMBER}, $main::VARS{RUN_NUMBER},
        $qsub_job_no);

}

1;


