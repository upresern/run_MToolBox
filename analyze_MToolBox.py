#!/usr/bin/env python3
import requests
import sys
import csv
import os

#=======================================================================================================================
#
#       FILE:  analyze_MToolBox.py
#       SHORT DESCRIPTION: the script analyzes the results of MToolBox.sh with MitoMaster Web API (https://www.mitomap.org/MITOMAP).
#       The results are saved in CSV file. This script is automatically run by 'run_MToolBox.sh' after successfully completing 'MToolBox.sh'
#       
#       VERSION:  1.0.0
#       CREATED:  07/03/2023
#=======================================================================================================================

#Two arguments need to be provided. The first argument is the full path to fasta file of previously generated mtDNA sequence.
#The second argument is the name of sample, which will be used for naming final csv file.
fastaFilePath = str(sys.argv[1])
sampleName = str(sys.argv[2])

#The script accesses MitoMaster Web API and gets results.
try:
    response = requests.post("https://mitomap.org/mitomaster/websrvc.cgi", files={"file": open(fastaFilePath),'fileType': ('', 'sequences'),'output':('', 'detail')})
    results = (str(response.content, 'utf-8'))
except requests.exceptions.HTTPError as err:
    print("HTTP error: " + err)
except:
    print("Error")

#CSV file with results is generated
resultsDirectory=os.path.dirname(fastaFilePath)
resultsFileName=resultsDirectory+'/'+sampleName+'-mitomaster_analysis.csv'

with open(resultsFileName, 'w') as f1:
    f1.write(results)
    f1.close()

print("Results of MitoMaster analysis of "+sampleName+" is saved in "+resultsFileName)



