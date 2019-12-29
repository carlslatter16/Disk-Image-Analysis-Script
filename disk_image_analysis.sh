#!/bin/bash

# A Script To Mount A Disk Image, Extract Metadata & Then Upload It To A SQL Database
#Author: Carl Slatter w18004969

arg1=$1 # Translating Argument Names For Readability And To Ensure They Are Global
arg2=$2
arg3=$3
arg4=$4

filedir=$(pwd) # Uses The Local Directory, The Intention Is That The User Calls The Script From Another Folder Using Path, While Being In The Working Directory That Everything Is Saved

function SQLManage() # A Function To Create An SQL Database And Table From A Metadata File
{
	rm sqlout.txt # This Attempts To Remove The Outputted File From The Script Last Time It Was Ran
		service mysql start # Starts The SQL Service If It's Not Already Started

	mysql -u root -pnorthumbria -t -e "DROP DATABASE IF EXISTS KF4005AL; CREATE DATABASE KF4005AL; /* This Deletes An Existing Database To Clean Up From Last Runtime & Creates A New One */
	USE KF4005AL; /* Selects The KF4005AL Database For Use */
	CREATE TABLE filedata (LastAccess DATETIME, LastModified DATETIME, Creation DATETIME, Permissions VARCHAR(10), UserID VARCHAR(5), GroupID VARCHAR(5), Filesize INT, FileName VARCHAR(60)); /* Creates SQL Table With Fields In Order */
	LOAD DATA LOCAL INFILE 'filedata.txt' INTO TABLE filedata;
	SELECT * FROM filedata ORDER BY LastAccess" > sqlout.txt # Imports Local Filedata.txt Into Filedata, And Then Lists It In Order Of Last Access Descending Into A File
	cat sqlout.txt # Prints Out The File
}

function MetaDataScraper() # A Function To Extract Metadata Given The Mount Folder Name & Directory To Scan
{
	statpath=$arg2/$directoryname # The Complete Path To Scan From The Pwd Above, Which Changes Everytime The Function Is Ran

	cd $filedir # Moves To The Directory To Save Files To

	echo ""
	echo "Scan Path: $statpath" # Prints The Scan Path For The User To Check What Is Being Read
	echo ""
	# These Statements Extract Metadata In The Requested Order, They Translate TABS & commars Into ; For The The Requested Format & Cuts The Dates To Make Them More Readable

	sudo stat -c %x $statpath/* | tr -s "\t" ";"| cut -b 1-19 > sTempA
	sudo stat -c %y $statpath/* | tr -s "\t" ";"| cut -b 1-19 > sTempB
	sudo stat -c %W $statpath/* | tr -s "\t" ";"| cut -b 1-19 > sTempC
	sudo stat -c %A $statpath/* | tr -s "," ";" > sTempD
	sudo stat -c %u $statpath/* | tr -s "," ";" > sTempE
	sudo stat -c %g $statpath/* | tr -s "," ";" > sTempF
	sudo stat -c %s $statpath/* | tr -s "," ";" > sTempG
	sudo stat -c %n $statpath/* | tr -s "," ";" > sTempH

	# The Above Statements Save To Temporary Files To Get Proper Formatting For The SQL Table

	paste sTemp* >> filedata.txt # All The Temp Files Are Pasted Into One File, Updating The File With Each Addition
	rm sTemp* # Removes All The Temporary Files To Clean Up After Itself
}

function DirRequest() # A Function To Ask The User About What Directories They Would Like To Scan If -D Is Not Present
{
	rm filedata.txt # Removes The Metadata From The Last Session

	dirscan="y" # Makes It So The Loop Will Iterate At Least Once

	while [ "$dirscan" = "y" ] # While The User Wants To Add New Directories To Scan
	do

	echo "What Directory Name Would You Like To Scan (Press ENTER If You To Scan For All Folders)?"

	read directoryname # Reads The Directory Name That The User Wants To Scan

	MetaDataScraper # Uses The Above Value In The Scraper

	echo "Do You Want To Scan Another Directory? [y][n]"

	read dirscan # If Anything But 'y' Is Returned, The User No Longer Wants To Scan For Directories

	done

	echo "Your Metadata should now be in /filedata.txt"
	file filedata.txt # Simply For Confirmation The File Is There

	SQLManage # Uses The Newly Extracted Metadata For The SQL Function
}

function DiskMount() # Mounts The Specified Disk Image To The Specified Location If Both Exist
{
mntpath=$arg2 # The Directory To Mount The Disk Image To, With The Given Location

if [ -e "$arg1" ]; then # If The First Argument (Disk Image) Exists
	echo "The File $arg1 Was Found"

	if [[ $arg2 != "" ]] # If The Second Argument (Mount Location) Isn't Empty
	then
		echo "The Folder $arg2 Was Entered"

	if [ -d "$mntpath" ]; then # If The Mount Location Exists
		echo "The Directory $2 Already Exists."

		if find $mntpath -mindepth 1 | read; then # If The Directory Is Empty/Occupied, Let The User Know
			echo "Directory Is Empty(Good)"
		else
			echo "Directory Is Already Populated (Will Attempt To Overwrite) "
		fi

		echo ""
		echo "Mounting..." # Simply Confirmation Of Progress For The User

		sudo mount -o loop,ro,offset=$((2048 * 512)) $filedir/$arg1 $mntpath # Mount In A loop To Iterate Through The Disk File, In Read Only Format, With A Specified Offset To A User Specified Location

		if [[ $arg3 != "-D" ]]; # If The Third Argument Is Not '-D', Ask The User For Directories
			then DirRequest
		fi

	else
		echo "The Directory $mntpath Does Not Exist, Will Attempt To Create One."
		sudo mkdir -p $mntpath # Creates The Directory & Path If They Do Not Already Exist
		echo "Mounting..."
		sudo mount -o loop,ro,offset=$((2048 * 512)) $filedir/$arg1 $mntpath # Mount In A loop To Iterate Through The Disk File, In Read Only Format, With A Specified Offset To A User Specified Location

		if [[ $arg3 != "-D" ]]; # If The Third Argument Is Not '-D', Ask The User For Directories
			then DirRequest
		fi
	fi

else
	echo "You Did Not Enter A Folder To Mount The Disk Image To"
fi
else
	echo "The File $arg1 Does Not Exist"
fi
}

function UserDirInputParser() # Converts The 4th Argument Into A Maximum Of Three Arguments That Can Be Used For Directory Scanning
{
	rm filedata.txt # Removes The Metadata From The Last Session

	commarcount="${arg4//[^,]}" # Counts The Commars From The 4th Argument

	organisedargs="$(echo "$arg4" | tr -s ","	" ")" # Converts Commars To Spaces After Commars Are Counted

		if [[ ${#commarcount} == "0" ]] # If There Are No Commars, There Must Be One Directory
		then
			directoryname=$organisedargs # Directory Name Equals The One Argument
			MetaDataScraper # Uses The Above Variable To Scrape
			SQLManage # After Scraping Is Finished, SQL Functionality Start

		elif [[ ${#commarcount} == "1" ]] # If One Commar Is Present, There Must Be Two Directories
		then
			directoryname=$(echo $organisedargs | head -n1 | awk '{print $1;}') # Directory Name Equals The First Element Of The Parsed String
			MetaDataScraper # Uses The Above Variable To Scrape

			directoryname=$(echo $organisedargs | head -n1 | awk '{print $2;}') # Directory Name Equals The Second Element Of The Parsed String
			MetaDataScraper # Uses The Updated Variable To Scrape

			SQLManage  # After Scraping Is Finished, SQL Functionality Start
		elif [[ ${#commarcount} == "2" ]] # If There Are Two Commars, There Must Be Three Directories
		then
			directoryname=$(echo $organisedargs | head -n1 | awk '{print $1;}') # Directory Name Equals The First Element Of The Parsed String
			MetaDataScraper # Uses The Updated Variable To Scrape

			directoryname=$(echo $organisedargs | head -n1 | awk '{print $2;}') # Directory Name Equals The Second Element Of The Parsed String
			MetaDataScraper # Uses The Updated Variable To Scrape

			directoryname=$(echo $organisedargs | head -n1 | awk '{print $3;}') # Directory Name Equals The Third Element Of The Parsed String
			MetaDataScraper # Uses The Updated Variable To Scrape

			SQLManage  # After Scraping Is Finished, SQL Functionality Start
		fi
}

function ArgumentControl() # Handles User Entered Arguments, For Functionality & Error Checking
{
if [[ $arg1 == "" ]]; # If No Arguments Are Entered, Print Usage Guide
	then
			 echo ""
			 echo "Standard Usage: <command> <localdiskimage> <pathtomountfolder>"
			 echo ""
			 echo "-D = This Allows The User To Specify Directories For The User To Scan, Delimited By Commar (max 3) I.E -D usr,bin,sbin"
			 echo "-S = This Allows The User To Skip And Specify A Mounted Image Folder & Go Straight To Extracting Metadata I.E -S MountedIsmage"
			 echo ""
			 echo "Note: -S Must Be The First Argument If Used, -D Can Only Be The Third Argument"
			 echo ""

elif [[ $arg1 == "-D" || $arg2 == "-D" ]]; # If The Directory Argument Is Given Without -S Or Mounting Information
	then
	echo "-D Cannot Be The First Or Second"

elif [[ $arg1 == "-S" && $arg2 == "" ]]; # If The First Argument Is To Skip, And The Second Argument Does Not Specify A Mounted Disk Image
		 then
		 echo "You Must Specify A Folder That Your Mounted Disc Image Resides At"

elif [[ $arg2 == "-S" || $arg3 == "-S" || $arg4 == "-S" ]] # If The -S Is Present Outside Of The First Argument
		then
		echo "The Skip Argument Must Be The First Argument"

elif [[ $arg1 != "-S" ]]; # If The First Argument Is Not To Skip Mounting
	then
		DiskMount # Run The Disk Mount Function
fi

if [[ $arg3 == "-D" && $arg4 != "" ]]; # If The Third Argument Is -D & The Next Argument Is Not Blank. This Is Used For Both Skipping Of Image Mounting & Normal Usage
	then UserDirInputParser #Parse The Entered Commar Delimited Directories

elif [[ $arg3 == "-D" && $arg4 == "" ]]; # If The Third Argument Is -D But No Directories Are Specified In The Next Argument
then echo "You Must Enter Directories To Scan After '-D'"
fi

if [[ $arg1 == "-S" && $arg2 != "" && $arg3 != "-D" ]]; # If The First Argument Is To Skip Mounting And The Mounted Folder Specified Is Entered And The User Is Not Giving Directories By Argument
then
	DirRequest # Asks The User For Directories To Scan As They Did Not Specify Any
fi
}

ArgumentControl # Opens When The Script Is Ran To Read Arguments
