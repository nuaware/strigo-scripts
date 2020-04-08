# strigo-scripts

Scripts for setting up nodes on Strigo training delivery platform

## Using these scripts

Create your own user_data.sh.PRIVATE from user_data.sh.template
- replace variables (do NOT archive under github !)

Copy/paste the contents of your user_data.sh.PRIVATE into the
"Scripts" section of each of your Strigo VMs (in Class definition).

## Recommendations for base image

- Install jq

- Include public key for ext. ssh access under ~user/.ssh/authorized_keys
  - limit source addresses

- Include public/private key for int. ssh access between nodes
  - limit source addresses to internal subnet

