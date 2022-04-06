# Debian Package Builder

1. Edit the version in Docker-compose.yaml 
2. Run the below command to generate DEB package
    ```
    $ docker-compose build
    $ docker-compose run deb-build 
    ```
3. DEB packages can be found in target folder.
    ```
    $ ls -l target/
    total 44
    drwxrwxr-x 4 obb obb  4096 Jun  4 04:20 jci-interface-1.0.0
    -rw-r--r-- 1 obb obb 37804 Jun  4 04:20 jci-interface-1.0.0.deb
    ```
