echo "/sbin/chkconfig --add ss-server" > /tmp/postinstall 
echo "/sbin/chkconfig --add ss-redir" >> /tmp/postinstall 

fpm -f -s dir -t rpm -n shadowsocks-libev --epoch 1 -v 1.44 \
--iteration 1.el6 -C /dev/shm/node-root \
-p ~/rpmbuild/RPMS/x86_64/ -d 'openssl >= 0.9.8' --post-install /tmp/postinstall .