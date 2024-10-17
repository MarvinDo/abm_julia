#!/bin/bash
set -e
set -o pipefail
set -o verbose

helpFunction()
{
   echo ""
   echo "Usage: $0 -p path -v version -n folder_name"
   echo "This script installs julia"
   echo -e "\t-p The path where it will be installed"
   echo -e "\t-p The major version. Eg. 1.10"
   echo -e "\t-p The minor version. Eg. 5"
   exit 1 # Exit script after printing help
}

while getopts "p:v:m:n:" opt
do
   case "$opt" in
      p ) basedir="$OPTARG" ;;
      v ) major="$OPTARG" ;;
      m ) minor="$OPTARG" ;;
      n ) foldername="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done


# Print helpFunction in case parameters are empty
if [ -z "$basedir" ] || [ -z "$major" ] || [ -z "$minor" ] || [ -z "$foldername" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# Begin script in case all parameters are correct
echo "Setting up julia $major.$minor in $basedir/$foldername..."


path=$basedir/$foldername
mkdir -p $path
cd $path


wget https://julialang-s3.julialang.org/bin/linux/x64/$major/julia-$major.$minor-linux-x86_64.tar.gz
tar zxvf julia-$major.$minor-linux-x86_64.tar.gz