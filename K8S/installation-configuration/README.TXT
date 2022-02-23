***All demos have been tested against Ubuntu 18.04 and Kubernetes 1.22.4***

If you have any issues please feel free to reach out.

aen@centinosystems.com or in the course discussion page at www.pluralsight.com

The course downloads have been updated and tested with 1.22.4. The installation of containerd and the bootstrapping of a cluster with kubeadm are 
dramatically simpler than in the 1.21 version which is what's in the course video at the moment.

- Key updates
1. Setting the systemd cgroup driver in config.toml...the two lines I added in the video are now there by default. You just have to change SystemdCgroup = false to SystemdCgroup = true
2. You no longer need to create and edit ClusterConfiguration.yaml 
3. kubeadm 1.22 removed the need to use the parameters --config=ClusterConfiguration.yaml and --cri-socket /run/containerd/containerd.sock these parameters are no longer needed


***All demos have been tested against Ubuntu 18.04 and Kubernetes 1.22.4***

There may be slight differences in the code from what's in the video course, but the concepts are all the same.

* Update 27 Dec 2021 
  * The course downloads have been updated and tested with 1.22.4. The installation of containerd and the bootstrapping of a cluster with kubeadm are 
dramatically simpler than in the 1.21 version which is what's in the course video at the moment.

* Key updates
  * Setting the systemd cgroup driver in config.toml...the two lines I added in the video are now there by default. You just have to change SystemdCgroup = false to SystemdCgroup = true
  * You no longer need to create and edit ClusterConfiguration.yaml 
  * kubeadm 1.22 removed the need to use the parameters --config=ClusterConfiguration.yaml and --cri-socket /run/containerd/containerd.sock these parameters are no longer needed


If you have any issues please feel free to reach out in the course discussion page and 

aen@centinosystems.com or in the course discussion page at www.pluralsight.com