

-- gnatmake p_ada_client.adb -o p_ada_client

with ada.exceptions;
with ada.text_io;
with ada.streams;

with gnat.sockets;


use type ada.streams.stream_element_offset;
use type gnat.sockets.socket_type;

procedure adaClient is

	-- Tamaño máximo del buffer en el que recibir los mensajes
	  maxBuffer : constant := 1024;

	  -- Subtipo de ada.streams.stream_element_array para almacenar un buffer de 1 hasta maxBuffer bytes.
	  --
	  -- ADA es un lenguaje robusto fuertemente tipado.
	  -- En caso de que maxBuffer fuese mayor que ada.streams.stream_element_offset'last se lanzaría una excepción de tipo constraint, en lugar de un comportamiento arbitrario.
	  subtype typeBuffer is ada.streams.stream_element_array (1 .. ada.streams.stream_element_offset (maxBuffer));

	  subtype typeMessage is string (1 .. maxBuffer);

	  socket : gnat.sockets.socket_type;

	procedure sendMessage (message : string) is

		-- Buffer de tipo stream que contiene el mensaje a enviar por el socket
		buffer : typeBuffer;

		for buffer'address use message'address;

		messageLength : ada.streams.stream_element_offset;

	  begin

		ada.text_io.put_line ("=>" & message);

		gnat.sockets.send_socket (socket => socket, item => buffer (1 .. message'length),  last => messageLength);

	end sendMessage;


	procedure receiveMessage is

		-- Buffer de tipo stream en el que se guarda el contenido leído del socket
		-- en su llamada a gnat.sockets.receive_socket
		buffer : typeBuffer;

		-- Buffer de tipo string para imprimir por pantalla el mensaje recibido
		message : typeMessage;

		-- Para "convertir" de tipo stream a tipo string mapeo directamente la dirección de memoria de message en la de buffer.
		-- Esto sería similar a crear un puntero message de tipo char inicializado al valor de buffer que sería un puntero de tipo void.
		-- Dado que por el socket se reciben caracteres ASCII imprimibles la impresión por pantalla será limpia, pero si se recibiesen caracteres no imprimibles,
		-- por ejemplo STX, se imprimirá algo ilegible tratando de representar STX.
		for message'address use buffer'address;

		messageLength : ada.streams.stream_element_offset;

	begin

		gnat.sockets.receive_socket (socket => socket, item => buffer, last => messagelength);

		-- Cuando se recibe longitud 0 es que el otro extremo ha cerrado la conexión, por lo que se procede a la desconexión del socket y al término de la ejecución
		if messageLength = 0 then

			gnat.sockets.close_socket (socket);

			ada.text_io.put_line ("Received disconnection");

		-- Cuando la conexión permanece activa pero no se recive información se lanza una excpción socket_error
		elsif messageLength > 0 then
		
			-- Mismo comentario que en el caso anterior: Si el tamaño recibido por el socket
			-- fuese mayor que el tamaño máximo del buffer se generaría una excepción de tipo
			-- constraint, en lugar de hacer un overflown escribiendo más allá de los límites
			-- de message
			if messageLength > ada.streams.stream_element_offset (maxBuffer) then

				ada.text_io.put_line ("Buffer size exceeded " & message (message'first .. maxBuffer));

			else
		  
				ada.text_io.put_line (message (message'first .. integer (messagelength)));

			end if;

		end if;

	end receiveMessage;
	
	
	procedure connect is
	  
		serverIP : constant STRING := "127.0.0.1";

		serverPort : constant := 13373;

		serverAddr : Gnat.sockets.sock_addr_type (gnat.sockets.family_inet);

	begin

		serverAddr.addr := gnat.sockets.inet_addr (serverIP);

		serverAddr.port := serverPort;

		gnat.sockets.create_socket (socket => socket);

		-- Conexión del socket. En caso de error se lanzaría una excepción de tipo socket_error, controlada en el procedimiento principal
		gnat.sockets.connect_socket (socket => socket, server => serveraddr);

		ada.text_io.put_line ("Connected");

	end connect;

begin

	connect;

	delay 0.5;

	-- Los primeros mensajes no se envían de una vez, sino en 3 mensajes distintos
	-- Por tanto se pueden recibir 3 mensajes o hacer un delay (línea #134)
	-- que de tiempo a que se envíen todos los mensajes y estén disponibles en el
	-- buffer al hacer el receive
	--for i in 1 .. 3 loop

	receiveMessage;

	--end loop;

	sendMessage ("challenge");

	receiveMessage;

	sendMessage ("2147483647");

	delay 0.5;

	receiveMessage;

	sendMessage ("613566947");

	delay 0.5;

	receiveMessage;

	exception
		when e : gnat.sockets.socket_error =>
			ada.text_io.put_line ("Socket error: " & ada.exceptions.exception_information (e));

end adaClient;