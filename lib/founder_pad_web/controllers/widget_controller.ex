defmodule FounderPadWeb.WidgetController do
  use FounderPadWeb, :controller

  def script(conn, %{"agent_id" => agent_id}) do
    host = FounderPadWeb.Endpoint.url()

    js = """
    (function() {
      var w = document.createElement('div');
      w.id = 'fp-widget';

      var btn = document.createElement('div');
      btn.id = 'fp-widget-btn';
      btn.style.cssText = 'position:fixed;bottom:20px;right:20px;width:56px;height:56px;border-radius:28px;background:#4648d4;color:white;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:0 4px 12px rgba(0,0,0,0.15);z-index:9999;font-size:24px;';
      btn.textContent = '\\u{1F4AC}';
      btn.addEventListener('click', function() {
        var chat = document.getElementById('fp-widget-chat');
        chat.style.display = chat.style.display === 'none' ? 'block' : 'none';
      });

      var chat = document.createElement('div');
      chat.id = 'fp-widget-chat';
      chat.style.cssText = 'display:none;position:fixed;bottom:86px;right:20px;width:380px;height:500px;border-radius:16px;overflow:hidden;box-shadow:0 8px 30px rgba(0,0,0,0.12);z-index:9998;';

      var iframe = document.createElement('iframe');
      iframe.src = '#{host}/widget/chat/#{agent_id}';
      iframe.style.cssText = 'width:100%;height:100%;border:none;';
      chat.appendChild(iframe);

      w.appendChild(btn);
      w.appendChild(chat);
      document.body.appendChild(w);
    })();
    """

    conn
    |> put_resp_content_type("application/javascript")
    |> send_resp(200, js)
  end

  def chat(conn, %{"agent_id" => _agent_id}) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Chat</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: system-ui, sans-serif; height: 100vh; display: flex; flex-direction: column; background: #fff; }
        .header { padding: 12px 16px; background: #4648d4; color: white; font-weight: 600; font-size: 14px; }
        .messages { flex: 1; overflow-y: auto; padding: 16px; }
        .msg { margin-bottom: 12px; padding: 8px 12px; border-radius: 12px; max-width: 80%; font-size: 14px; line-height: 1.4; }
        .msg.bot { background: #f3f4f6; }
        .msg.user { background: #4648d4; color: white; margin-left: auto; }
        .input-area { padding: 12px; border-top: 1px solid #e5e7eb; display: flex; gap: 8px; }
        .input-area input { flex: 1; padding: 8px 12px; border: 1px solid #d1d5db; border-radius: 8px; outline: none; font-size: 14px; }
        .input-area button { padding: 8px 16px; background: #4648d4; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; }
      </style>
    </head>
    <body>
      <div class="header">FounderPad Assistant</div>
      <div class="messages" id="messages">
        <div class="msg bot">Hi! How can I help you today?</div>
      </div>
      <div class="input-area">
        <input type="text" id="input" placeholder="Type a message..." onkeypress="if(event.key==='Enter')sendMsg()">
        <button onclick="sendMsg()">Send</button>
      </div>
      <script>
        function sendMsg() {
          var input = document.getElementById('input');
          var msg = input.value.trim();
          if (!msg) return;
          var messages = document.getElementById('messages');
          var userDiv = document.createElement('div');
          userDiv.className = 'msg user';
          userDiv.textContent = msg;
          messages.appendChild(userDiv);
          input.value = '';
          messages.scrollTop = messages.scrollHeight;
          setTimeout(function() {
            var botDiv = document.createElement('div');
            botDiv.className = 'msg bot';
            botDiv.textContent = 'Thanks for your message! This is a demo widget. Connect to your agent API for real responses.';
            messages.appendChild(botDiv);
            messages.scrollTop = messages.scrollHeight;
          }, 1000);
        }
      </script>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end
end
