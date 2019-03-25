love.load = function()
  nodes = {}
  node_size = 16
  current_node = 0
  current_edge = false
end

love.update = function(dt)
  local mx, my = love.mouse.getPosition()
  for i, v in ipairs(nodes) do
    if v.delete then
      v.size = lerp(v.size, 0, dt)
      if v.size == 0 then
        table.remove(nodes, i)
        break
      end
    elseif v.prompt == true or (current_edge and (v.edges[opposite_edge(current_edge)] > 0 or node_contains(v, current_node))) then
      v.size = lerp(v.size, .5, dt)
    elseif current_edge and pythag(mx, my, v.x, v.y) < node_size then
      v.size = lerp(v.size, 1.2, dt)
    else
      v.size = lerp(v.size, 1, dt)
    end

    if not current_edge and not v.delete then
      if not v.active and pythag(mx, my, v.x, v.y) < node_size then
        v.active = true
        current_node = i
      elseif v.active and pythag(mx, my, v.x, v.y) > node_size*3 then
        v.active = false
        current_node = 0
      elseif v.active and pythag(mx, my, v.x, v.y) > node_size then
        v.prompt = false
      end
    end

    if v.clicked then
      if math.abs(mx-v.clicked.x) > 2 or math.abs(my-v.clicked.y) > 2 then
        v.dragged = true
        v.clicked = false
      elseif os.clock()-v.clicked.time > .1 then
        v.prompt = not love.mouse.isDown(1)
        v.dragged = love.mouse.isDown(1)
        v.clicked = false
      end
    end

    if v.dragged then
      v.dx = mx
      v.dy = my
      v.active = false
      if not love.mouse.isDown(1) then
        v.dragged = false
      end
    end

    if v.active then
      v.menu_size = lerp(v.menu_size, 1, dt)
    elseif not v.active then
      v.menu_size = lerp(v.menu_size, 0, dt)
    end

    v.x = lerp(v.x, v.dx, dt)
    v.y = lerp(v.y, v.dy, dt)
  end
end

love.draw = function()
  love.graphics.setLineWidth(node_size/4)
  for i, v in ipairs(nodes) do
    if not v.delete then

      if v.edges.right > 0 then
        love.graphics.line(v.x, v.y, nodes[v.edges.right].x, nodes[v.edges.right].y)
      end
      if v.edges.down > 0 then
        love.graphics.line(v.x, v.y, nodes[v.edges.down].x, nodes[v.edges.down].y)
      end
    end
  end
  love.graphics.setLineWidth(2)
  for i, v in ipairs(nodes) do
    if v.active or v.menu_size > 0 then
      love.graphics.setColor(.5, .5, .5, .5)
      love.graphics.circle("fill", v.x, v.y, v.menu_size*node_size*3)
      love.graphics.setColor(1, 1, 1)

      love.graphics.circle(circle_type(v.edges.up), v.x, v.y-node_size*v.menu_size*2, v.menu_size*node_size*.5)
      love.graphics.circle(circle_type(v.edges.down), v.x, v.y+node_size*v.menu_size*2, v.menu_size*node_size*.5)
      love.graphics.circle(circle_type(v.edges.left), v.x-node_size*v.menu_size*2, v.y, v.menu_size*node_size*.5)
      love.graphics.circle(circle_type(v.edges.right), v.x+node_size*v.menu_size*2, v.y, v.menu_size*node_size*.5)
    end

    love.graphics.circle("fill", v.x, v.y, v.size*node_size)
  end

  if current_edge then
    love.graphics.setLineWidth(node_size/4)
    local mx, my = love.mouse.getPosition()
    love.graphics.line(nodes[current_node].x, nodes[current_node].y, mx, my)
  end
end

love.mousepressed = function(x, y, button)
  if current_edge then -- node 1 already selected, looking for second end
    for i, v in ipairs(nodes) do -- see if player is clicking a node
      if pythag(x, y, v.x, v.y) < node_size and i ~= current_node and v.edges[opposite_edge(current_edge)] == 0 and not node_contains(v, current_node) and not v.delete then
        nodes[current_node].edges[current_edge] = i -- set destination of node 1's edge
        v.edges[opposite_edge(current_edge)] = current_node -- set destination of node 2's edge
        break
      end
    end
    current_edge = false -- reset
    current_node = 0
  else
    if current_node == 0 then -- create new node
      nodes[#nodes+1] = {x = x, y = y, edges = {up = 0, down = 0, left = 0, right = 0}, dx = x, dy = y, size = 0, menu_size = 0, active = false, prompt = false, delete = false, clicked = false, dragged = false}
    else
      local node = nodes[current_node]
      if pythag(x, y, node.x, node.y-node_size*2) < node_size*.5 then
        current_edge = "up"
      elseif pythag(x, y, node.x, node.y+node_size*2) < node_size*.5 then
        current_edge = "down"
      elseif pythag(x, y, node.x-node_size*2, node.y) < node_size*.5 then
        current_edge = "left"
      elseif pythag(x, y, node.x+node_size*2, node.y) < node_size*.5 then
        current_edge = "right"
      else
        current_edge = false
      end
      if current_edge then
        if node.edges[current_edge] > 0 then -- free up edge if it's already filled
          nodes[node.edges[current_edge]].edges[opposite_edge(current_edge)] = 0
          node.edges[current_edge] = 0
          current_edge = false
        else
          node.active = false
        end
      end

      if pythag(x, y, node.x, node.y) < node_size then -- player clicked node
        node.clicked = {time = os.clock(), x = x, y = y}
        if node.prompt == true then
          node.delete = true
          node.active = false
          for k, v in pairs(node.edges) do
            if v > 0 then
              nodes[v].edges[opposite_edge(k)] = 0
            end
          end
          current_node = 0
        end
      end
    end
  end
end

love.keypressed = function(key)
  file, errorstr = love.filesystem.newFile("New Map "..os.date("%m-%d-%Y %H.%M.%S")..".txt", "w")
  file:write("nodes = {\r\n")
  for i, v in ipairs(nodes) do
    file:write("{x = "..tostring(v.x)..", y = "..tostring(v.y)..", edges = {up = "..tostring(v.edges.up)..", down = "..tostring(v.edges.down)..", left = "..tostring(v.edges.left)..", right = "..tostring(v.edges.right).."}},\r\n")
  end
  file:write("}")
  file:close()
end

pythag = function(x1, y1, x2, y2)
  return math.sqrt((x2-x1)*(x2-x1)+(y2-y1)*(y2-y1))
end

lerp = function(num, goal, dt)
  local value = num+((goal-num)/8)*dt*60
  if math.abs(value-goal) < .02 then
    return goal
  else
    return value
  end
end

circle_type = function(edge)
  if edge > 0 then
    return "fill"
  else
    return "line"
  end
end

opposite_edge = function(edge)
  if edge == "up" then return "down"
  elseif edge == "down" then return "up"
  elseif edge == "left" then return "right"
  elseif edge == "right" then return "left"
  end
end

node_contains = function(v, num)
  return (v.edges.up == num or v.edges.down == num or v.edges.left == num or v.edges.right == num)
end
