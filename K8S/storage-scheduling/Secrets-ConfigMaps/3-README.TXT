Hi there, as you know we've changed the container runtime from docker to containerd for this series of courses. 

In this demo you will pull, tag and then push a container image to a private repository and then use the image in a private repository in a Deployment. 
Please use the correct demo file based on the container runtime you're running in your cluster. 

*** If your cluster is using *docker* as a container runtime, this demo uses docker tools to pull/tag/push a test image to a private repo
    Use the demo file 3-PrivateContainerRegistry.sh

*** If your cluster us using *containerd* as a container runtime, this demo uses ctr to pull/tag/push a test image to a private repo
    Use the demo file 3-PrivateContainerRegistry-ctr.sh

I will be updating the video for this course later this summer to reflect this change.

If you have any questions please reach out to me at aen@centinosystems.com 
