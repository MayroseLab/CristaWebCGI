#!/usr/bin/perl -w

use warnings FATAL => 'all';
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use lib "/bioseq/bioSequence_scripts_and_constants";
use GENERAL_CONSTANTS;
use BIOSEQUENCE_FUNCTIONS;
use lib "/data/www/cgi-bin/crista";
use CRISTA_GLOBALS;


###########################################
###### CRISTA SERVER
###### Version 1.0 
###### September 2016
###########################################

###### READING DATA FROM FORM
###### this command = "extract data from the HTML.

$query = new CGI;

###### this command = take the name of the path of files from the HTML
$sgRNA_seqs_input = $query->param('sgRNA_seqs');
$genomeAssembly = $query->param('genomeAssembly');

### VARS WILL HOLD ALL GLOBAL VARS
our %VARS = ();

$VARS{user_email} = $query->param('email_add');
$VARS{JOB_TITLE} = $query->param('JOB_TITLE');
$VARS{RUNNING_MODE} = "Detect possible off-targets throughout the genome for multiple sgRNAs";
$VARS{RUNNING_PARAMS_TEXT} = "sgRNAs: ".$sgRNA_seqs_input."<br>"; #to be continued

###### This part creates a folder for each execution (same as static in c++)

$VARS{RUN_NUMBER} = $^T;

###### WorkingDir is where the results of the current run will be.
###### resultsDir is where the results will be.
###### WWWdir is where the web page is.

$VARS{resultsDir} = "/bioseq/data/results/crista/";
$VARS{WorkingDir} = $VARS{resultsDir}.$VARS{RUN_NUMBER}."/";
while (-e $VARS{WorkingDir})
{
    $VARS{RUN_NUMBER} = $^T;
    $VARS{WorkingDir} = $VARS{resultsDir}.$VARS{RUN_NUMBER}."/";
}

$VARS{logs_dir} = GENERAL_CONSTANTS::SERVERS_LOGS_DIR."crista/";
$VARS{OutLogFile} = $VARS{logs_dir}.$VARS{RUN_NUMBER}.".log";

$VARS{WWWdir} = GENERAL_CONSTANTS::CRISTA_URL."results/".$VARS{RUN_NUMBER}."/";
$VARS{run_url} = $VARS{WWWdir}."output.php";

###### Name of the program.
$VARS{crista_exec_file} = "/bioseq/crista/CRISTA_online/multiple_sgRNAs_offtargets_search.py";

###### form variables
$sgRNA_seqs_input =~ s/\s/,/g;
$VARS{sgRNA_seqs} = $sgRNA_seqs_input;
$VARS{genomeAssembly} = $genomeAssembly;

###### here we set the html output file (where links to all files will be)

$VARS{OutHtmlFile} = $VARS{WorkingDir}."output.php";
$VARS{RUNNING_PARAMS_TEXT} = $VARS{RUNNING_PARAMS_TEXT}."Genome assembly: ".$VARS{genomeAssembly}."<br>";


#$VARS{OutHtmlFile} = $VARS{WorkingDir} . "output.html"; 
###### here we set the reload interval (in seconds).

$VARS{reload_interval} = 30;

###### here we set the email of the server - for problems...
$VARS{DEVELOPER_MAIL} = GENERAL_CONSTANTS::ADMIN_EMAIL;
$VARS{mail} = "\"mailto:".$VARS{DEVELOPER_MAIL}."?subject=CRISTA%20Run%20No.:%20".$VARS{RUN_NUMBER}."\"";

###### Send mail Global VARS
$VARS{send_email_dir} = GENERAL_CONSTANTS::SEND_EMAIL_DIR_IBIS;
$VARS{smtp_server} = GENERAL_CONSTANTS::SMTP_SERVER;
$VARS{userName} = GENERAL_CONSTANTS::ADMIN_USER_NAME;
$VARS{userPass} = GENERAL_CONSTANTS::ADMIN_PASSWORD;

###### here we set the error definitions.

$VARS{ErrorDef} = "<font size=+3 color='red'>ERROR! CRISTA session has been terminated: </font>";
$VARS{SysErrorDef} = "<p><font size=+3 color='red'>SYSTEM ERROR - CRISTA session has been terminated!</font><br><b>Please wait for a while and try to run CRISTA again</b></p>\n";
$VARS{ContactDef} = "\n<H3><center>For assistance please <a href=".$VARS{mail}.">contact us</a> and mention this number: ".$VARS{RUN_NUMBER}."</H3>\n";

###### here we split the program for 2 processes.
###### the first will be the main program - which will keep running
###### the second will be a window telling the user to wait, and that
###### it will be updated every x seconds...

###### FATHER is the program now.
###### pid = process ID
###### the new process which is the son has pid of 0.
###### the father process has a pid which is the ID of the son.



###### forking... TO BE DONE BEFORE LONG PROCESS
if ($pid = fork) {
    exit;
}

###### ******************************
###### FATHER ######
elsif (defined $pid) {
    &process_main;
    &CRISTA_GLOBALS::Update_Users_Log;
}

###### IF some problem for CHILD process to start
else {
    die "Can not fork the process, please contact $VARS{mail}\n";
}

###### here we set the permission of all files so that they can be read from the web.

system 'echo "(cd '.$VARS{WorkingDir}.' ; chmod -R og+rx * )" | /bin/tcsh';
chmod 0600, $VARS{WorkingDir}."user_email.txt";

exit;
###### MAIN ENDS HERE ######

###################################################################################

sub process_main {
    ##### here we create a new dir for this run. 
    &CRISTA_GLOBALS::create_new_dir;

    ###### open the log file
    system 'echo "(touch '.$VARS{OutLogFile}.'; chmod oug+w '.$VARS{OutLogFile}.')" | /bin/tcsh';
    open LOG, ">$VARS{OutLogFile}";
    print LOG "\n************** LOG FILE *****************\n\n";
    print LOG "Begin time: ".BIOSEQUENCE_FUNCTIONS::printTime()."\n";
    if ($VARS{user_email} ne "") {
        print LOG "User email is: $VARS{user_email}\n";
        open USER_MAIL, ">".$VARS{WorkingDir}."user_email.txt";
        print USER_MAIL $VARS{user_email};
        close USER_MAIL;
        chmod 0600, $VARS{WorkingDir}."user_email.txt";
    }
    else {
        print LOG "User has not given his email\n";
    }
    close LOG;

    ###### CREATE AND START file for output UPDATE
    &CRISTA_GLOBALS::start_output_html;


    ###### Move directly to the output file
    print "Location: ".$VARS{run_url}."\n\n";

    ###### disconnecting CHILD flush buffers  
    close(STDIN);
    close(STDOUT);
    close(STDERR);

    ###### Verifying that user supplied an sgRNA_seq :
    #my $validate_sgseq = CRISTA_GLOBALS::validate_nuc_seq_length("sgRNA sequence", $VARS{sgRNA_seq}, 20);
    
    ######################################################
    ## TODO add more validations
    ######################################################
    ###### Verifying that user supplied a file:
#    if ($validate_sgseq ne "OK")
#	{
#		### sgRNA seq not supplied
#		$err1 = "sgRNA sequence is mandatory. Aborting. ";
#		open LOG, ">>$VARS{OutLogFile}";
#		print LOG "$err1";
#		close LOG;
#		open OUTPUT, ">>".$VARS{OutHtmlFile};
#		print OUTPUT "$err1";
#		close OUTPUT;
#		&CRISTA_GLOBALS::stop_reload;
#		exit;
#	}
#
    &run_calc;
    return;
}



#########################################################################################
###### CALCULATION AND POST-PROCESSING
sub run_calc {
    my $crista_comm;
    $crista_comm = "$VARS{crista_exec_file} -s $VARS{sgRNA_seqs} -g $VARS{genomeAssembly}";
    $crista_comm = $crista_comm." -p $VARS{WorkingDir} -n $VARS{RUN_NUMBER}";

    #$crista_comm = $crista_comm." > $VARS{WorkingDir}"."std";
    
	CRISTA_GLOBALS::send_to_queue($crista_comm)
}
