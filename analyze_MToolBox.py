#!/usr/bin/env python3
import requests
import sys
import csv
import os
import argparse

'''
    FILE:  analyze_MToolBox.py
    SHORT DESCRIPTION: the script analyzes the results of MToolBox.sh with MitoMaster Web API (https://www.mitomap.org/MITOMAP).
    The results are saved in CSV file. This script is automatically run by 'run_MToolBox.sh' after successfully completing 'MToolBox.sh'
        
    VERSION:  1.0.0
    CREATED:  07/03/2023
'''

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('-f', '--fastaFile', required=True, help='Path to fasta file.')
parser.add_argument('-r', '--resultsName', required=True, help='Desired name of the csv file with results.')

args = parser.parse_args()

fastaFilePath = args.fastaFile
resultsName = args.resultsName

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
resultsFullPath=resultsDirectory + '/' + resultsName

with open(resultsFullPath, 'w') as resultsFile:
    resultsFile.write(results)
    resultsFile.close()

print("Results of MitoMaster analysis is saved in "+resultsFullPath)