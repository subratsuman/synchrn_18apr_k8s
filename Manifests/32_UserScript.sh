#!/bin/bash


#To take from the admin-cluster config (to modify)
certificate_data="LS0tLS1CRUdJTiBDRVJUSUZJQ0FUR5dTZuQW15THZiTjA5Tnh1SFIxS09PMHBTV1pXbDMycmxKOEhHM0RJZGhvOExPYkllalRiRC9xakxmdUdoCjlJeFhjYmEwUmdxRlROKytmcy9FL2M1WkFrZzFBcTBNa3B2cEFlT0NHQzU2RzRzN1R4NEg1YVVtMzYwQmF3ZzAKRVhlMWhNUlZHTitoZFNpUjloenZzUUQ5Tmc5b2xpWW13VmlaWVRRZU5JMTRoM1lGWSszb0ZEYzlyVitXQVJVagpHaWNINi80TVhPWCtKbi9wRzdjQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZCVElQYUpwSXUreDhJSFJ2dXNDc1lXSTBtcE5NQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBS0pNZWtNSk1PVkIySVI2K1NUaworNTdsTGNCdFBaTENHZnNOVExyTVVaVXMxVDMyUnJ0dkVkZVcwNDAyTlVvL1pQL1ZDRTJzRUlrNEN6WlNhbFdpCjFhb0lUS3puVTBSTjNOb21wMlNMdCszRUxhZkVSMVUxZHg5UC9yQzlNUVJ2OWx4VVZBV3VGNWUwNHAxcldyTVoKb0NxNm1tVEZhWDZTbzBxTnh0NGdpS0pPaG1oWXFQVDVSejNzVHdlQjhUK1dybXpuQ1hQU1F3ekRBdm1xeWUzagpjYkF0eWdTWG1sVmxlTURyVDhMVWljbXJFekxSL3VsdCt1NEFtaGZ0ekR5ZERCYXh1UXplN3BKdXB6Mmp1OHlnCkMrdGVFTnpodGtBRkh2RnRuZENXVDcvcGMrSjlWQTlIS3I5WHVzRVQreE5oc3BCcWMrb2FocVk3MkxSRmlZa2wKaWRJPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
server="https://172.31.82.130:6443"

#The default path for Kubernetes CA
ca_path="/etc/kubernetes/pki"

#The default name for the Kubernetes cluster
cluster_name="kubernetes"


create_user() {

	#Create the user
	printf "User creation\n"
	useradd -m $user

	#Create private Key for the user
	printf "Private Key creation\n"
	openssl genrsa -out $filename.key 2048

	#Create the CSR
	printf "\nCSR Creation\n"
	if [ $group == "None" ]; then
		openssl req -new -key $filename.key -out $filename.csr -subj "/CN=$user"
	else
		openssl req -new -key $filename.key -out $filename.csr -subj "/CN=$user/O=$group"
	fi 

	#Sign the CSR 
	printf "\nCertificate Creation\n"
	openssl x509 -req -in $filename.csr -CA $ca_path/ca.crt -CAkey $ca_path/ca.key -CAcreateserial -out $filename.crt -days $days

	#Create the .certs and mv the cert file in it
	printf "\nCreate .certs directory and move the certificates in it\n" 
	mkdir $user_home/.certs && mv $filename.* $user_home/.certs

	#Create the credentials inside kubernetes
	printf "\nCredentials creation\n"
	kubectl config set-credentials $user --client-certificate=$user_home/.certs/$user.crt  --client-key=$user_home/.certs/$user.key

	#Create the context for the user
	printf "\nContext Creation\n"
	kubectl config set-context $user-context --cluster=$cluster_name --user=$user

	#Edit the config file
	printf "\nConfig file edition\n"
	mkdir $user_home/.kube
	cat <<-EOF > $user_home/.kube/config
	apiVersion: v1
	clusters:
	- cluster:
	    certificate-authority-data: $certificate_data
	    server: $server
	  name: $cluster_name
	contexts:
	- context:
	    cluster: $cluster_name
	    user: $user
	  name: $user-context
	current-context: $user-context
	kind: Config
	preferences: {}
	users:
	- name: $user
	  user:
	    client-certificate: $user_home/.certs/$user.crt
	    client-key: $user_home/.certs/$user.key
	EOF
	
	#Change the the ownership of the directory and all the files
	printf "\nOwnership update\n"
	sudo chown -R $user: $user_home



}




response=
echo "Give the CN of the user : "
read response
if [ -n "$response" ]; then
	
	user=$response
	
	echo "Give the Group of the user (If there is no group left it blank): "
	read response
	if [ -n "$response" ];then
		group=$response
	else
		group="None"
	fi

	echo "Give the number of days for the certificate (360 days by default if you left it blank): "
	read response
	if [ -n "$response" ];then
		days=$response
	else
		days=360
	fi

	
	#Set up variables
	user_home="/home/$user"
	filename=$user_home/$user
	
	echo "------------------------------------"
	
	#Execute the function create_user
	create_user
	exit

else
	echo "Username is required"
	exit
fi

