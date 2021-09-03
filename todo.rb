require "sinatra"
require "sinatra/reloader" if development?
require 'sinatra/content_for'
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def completed?(list)
    return false if list[:todos].size.zero?
    list[:todos].all? do |todo|
      todo[:completed] == true
    end
  end

  def n_remaining(list)
    list[:todos].reduce(0) do |acc, todo|
      if todo[:completed] == false
        acc + 1
      else
        acc
      end
    end
  end
end

get "/" do
  redirect "/lists"
end

# GET /lists          -> view all lists
# GET /lists/new      -> new list form
# POST /lists         -> create a new list
# GET /lists/1        -> view a single list
# GET /users
# GET /users/1

get "/lists" do
  @lists = session[:lists]

  @lists.sort_by! { |a| completed?(a) ? 1 : 0 }

  erb :lists, layout: :layout
end

# Return an error messsage if the name is invalid. Return nil otherwise
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters"
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique"
  end
end

def next_list_id(lists)
  return 0 if lists.empty?

  max = lists.max_by { |list| list[:id] }[:id]
  max + 1
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# View list
get "/lists/:id" do
  @id = params[:id].to_i
  if @list = session[:lists].find { |list| list[:id] == @id }
    @list[:todos].sort_by! { |todo| todo[:completed] ? 1 : 0 }
    erb :list, layout: :layout
  else
    session[:error] = "The specified list was not found"
    redirect "/lists"
  end
end

# Edit an existing todo list
get "/list/:id/edit" do
  @id = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @id }

  erb :edit_list, layout: :layout
end

# Update list
post "/lists/:id" do
  list_name = params[:list_name].strip
  @id = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @id }

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The update was successful."
    redirect "/lists/#{@id}"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  @id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == @id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted"
    redirect "/lists"
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters"
  end
end

def next_todo_id(todos)
  return 0 if todos.empty?

  max = todos.max_by { |todo| todo[:id] }[:id]
  max + 1
end

# Add todo
post "/lists/:list_id/todos" do
  list_id = params[:list_id].to_i
  @id = list_id
  @list = session[:lists].find { |list| list[:id] == @id }

  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }
    session[:success] = "The todo was added successfully."
    redirect "/lists/#{list_id}"
  end
end

# Delete todo
post "/lists/:list_id/todos/:todo_id/destroy" do
  list_id = params[:list_id].to_i
  todos = session[:lists].find { |list| list[:id] == list_id }[:todos]
  todo_id = params[:todo_id].to_i
  a = todos.detect { |todo| todo[:id] == todo_id }
  idx = todos.find_index(a)
  todos.delete_at(idx)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted"
    redirect "/lists/#{list_id}"
  end
end

# Update status of todo
post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  list = session[:lists].find { |list| list[:id] == list_id }

  is_completed = params[:completed] == "true"

  the_todo = list[:todos].detect { |todo| todo[:id] == todo_id }
  idx = list[:todos].find_index(the_todo)
  list[:todos][idx][:completed] = is_completed

  session[:success] = "The todo has been updated"
  redirect "/lists/#{list_id}"
end

# Mark all todos as complete
post "/lists/:list_id/complete_all" do
  list_id = params[:list_id].to_i
  list = session[:lists].find { |list| list[:id] == list_id }

  list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "The list has been completed"
  redirect "/lists/#{list_id}"
end
