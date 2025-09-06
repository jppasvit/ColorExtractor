
export const Camera = {
    mounted() {
        const video = this.el.querySelector("#video");
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices.getUserMedia({ video: true })
                .then(stream => {
                    video.srcObject = stream;
                    video.play();
                })
                .catch(err => {
                    console.error("Error accessing camera: ", err);
                });
        } else {
            console.error("Camera API not supported");
        }
    }
}

