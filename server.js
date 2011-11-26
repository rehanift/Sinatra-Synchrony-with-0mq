var context = require('zmq');

var pull_socket = context.createSocket('pull');
pull_socket.bind("tcp://127.0.0.1:5555", function(err){
    if(err) throw err;
    console.log("Pull socket bound");
});

var pub_socket = context.createSocket('publisher');
pub_socket.bind("tcp://127.0.0.1:5556", function(err){
    if(err) throw err;
    console.log("Publishing socket bound");
});

pull_socket.on("message", function(message){
    console.log("message received: " + message.toString());
    /*if (Math.random() * 1000 > 950) {
	console.log("========== waiting ==========");
	setTimeout(function(){
	    pub_socket.send(message);
	    console.log("message sent");	    
	},5000);
    } else {
	pub_socket.send(message);
	console.log("message sent");
    }*/
    pub_socket.send(message);
    console.log("message sent");
});