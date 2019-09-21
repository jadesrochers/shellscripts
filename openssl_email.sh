#!/bin/bash
charge=50
dest="gookiepile@yahoo.com"
(printf %"sHELO localhost\n"; 
sleep 1; 
printf %"sAUTH PLAIN AGlkZW50ZXZlbnRAZ21haWwuY29tAENlcmVTY29wZTIwMTY=\n"; 
sleep 2; 
printf %"sMAIL FROM: <identevent@gmail.com>\n"; 
sleep 1;  
printf "rcpt to:  <%s>\n" ${dest%%,*}; 
sleep 1; 
printf %"sDATA\n"; 
sleep 1; 
printf "Subject: CereScope Battery Notice (Down to %s%%)\n\nThe battery has fallen to %s percent charge\n\n" $charge $charge; 
printf "hostname: %s\n\n" $(hostname); 
printf %"s\n.\n"; 
sleep 2; 
printf %"squit\n") | openssl s_client -connect smtp.gmail.com:465 -crlf -ign_eof
