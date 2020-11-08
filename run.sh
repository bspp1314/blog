#/bin/bash 
#cd public 
#git add --all 
#msg="clean site `date +%Y-%m-%d:%H:%M:%S`"
#echo $msg 
#git commit -m "$msg"
#cd ../ 

rm -rf public/*  
hugo -t even  
cd public 
git config --local user.name  "bspp1314"
git config --local user.email "linyuanpeng1314@gmail.com"
git add --all 
msg="update site `date +%Y-%m-%d:%H:%M:%S`"
echo $msg 
git commit -m "$msg"
git push 


#git init 
#git remote add origin https://github.com/bspp1314/bspp1314.github.io.git 
 
#git push 
#git push -f -u origin master  
#cd ../
#rm -rf public 
