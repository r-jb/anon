# Anon
 A collection of scripts to be as anonymous as one can be on the internet with the focus on simplicity and performance.
 Currently only supported on kali-linux.

## Install
Copy and paste this in your terminal for a quick install.

`$ curl -fsSL https://github.com/r-jb/anon/raw/main/install.sh | sh`

## Usage

### Show usage
`$ sudo anon webui`

### Start the webui module
`$ sudo anon webui start`

### Stop the webui module
`$ sudo anon webui stop`

### Check the webui status
`$ sudo anon webui`

## Update
To update, just execute the install script once again.

To force the update, or skip confirmations, execute the script with -y, or use this one liner:

`$ curl -fsSL https://github.com/r-jb/anon/raw/main/install.sh | sh -s -- -y`