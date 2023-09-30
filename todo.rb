require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def todos_count(list)
    list[:todos].count
  end

  def list_completed?(list)
    !list[:todos].empty? && todos_completed_count(list) == todos_count(list)
  end

  def todos_completed_count(list)
    list[:todos].select { |todo| todo[:completed] }.count
  end

  def list_class(list)
    'complete' if list_completed?(list)
  end
=begin

  lists =
  [
    {
      :name=>"AJ 1", :todos=>[
                                {:name=>"Test", :completed=>true},
                                {:name=>"Test 2", :completed=>true},
                                {:name=>"Test 3", :completed=>true}
                             ]
    },
    {
      :name=>"I did it!", :todos=>[
                                    {:name=>"Step 1", :completed=>false}, {:name=>"Step 2", :completed=>true}, {:name=>"Step 3", :completed=>true}
                                  ]
    }
  ]
  "AJ 1" > Completed (set value to 1?) List ID = 0
  "I did it!" > Incomplete (set value to 0) List ID = 1

=end
  def sort_completed_lists(lists, &block)
    # Iterate lists with index, add list and idx as nested subarrays
    sorted_arr = []
    lists.each_with_index { |list, list_idx| sorted_arr << [list, list_idx] }

    # Sort the subarrays based off of the lists todos being completed
    sorted_arr = sorted_arr.sort_by { |subarr| list_completed?(subarr[0]) ? 1 : 0 }

    # Iterate the array, yield each list/list_idx for client rendering
    sorted_arr.each(&block)
  end

  def sort_completed_todos(todos, &block)
    # Iterate todos with index, add todo and idx as nested subarrays
    sorted_arr = []
    todos.each_with_index { |todo, todo_idx| sorted_arr << [todo, todo_idx] }

    # Sort the subarrays based off of the todos being completed
    sorted_arr = sorted_arr.sort_by { |subarr| subarr[0][:completed] == true ? 1 : 0 }

    # Iterate the array, yield each todo/todo_idx for client rendering
    sorted_arr.each(&block)
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET   /lists      -> view all lists
# GET   /lists/new  -> new list form
# POST  /lists      -> create new list
# GET   /lists/1    -> view a single list

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# View single list
get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Render the edit list form
get '/lists/:list_id/edit_list' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(list_name)
  if !(1..100).cover? list_name.size
    'Please enter a list name between 1 and 100 characters long.'
  elsif session[:lists].any? { |list| list[:name] == list_name }
    "\"#{list_name}\" already exists. Please enter unique list name between 1 and 100 characters long."
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Edit list name
post '/lists/:list_id' do
  new_list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = new_list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete entire list
post '/lists/:list_id/delete_list' do
  @list_id = params[:list_id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = 'The list has been deleted successfully.'
  redirect '/lists'
end

# Return an error message if the todo name is invalid. Return nil if name is valid.
def error_for_todo_name(todo_name, list)
  if !(1..100).cover? todo_name.size
    'Please enter a todo name between 1 and 100 characters long.'
    # elsif list[:todos].any? { |todo| todo[:name] == todo_name }
    # "\"#{todo_name}\" already exists. Please enter unique todo name between 1 and 100 characters long."
  end
end

# Create new todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_name = params[:todo].strip

  error = error_for_todo_name(todo_name, @list)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo_name, completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete todo item
post '/lists/:list_id/todos/:todo_id/delete_todo' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @todo_id = params[:todo_id].to_i
  @list[:todos].delete_at(@todo_id)

  session[:success] = 'The todo has been deleted successfully.'
  redirect "/lists/#{@list_id}"
end

# Mark single todo complete/incomplete
post '/lists/:list_id/todos/:todo_id/change_state' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @todo_id = params[:todo_id].to_i
  todo = @list[:todos][@todo_id]

  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed
  session[:success] = 'The todo has been updated'
  redirect "/lists/#{@list_id}"
end

# Mark all todos in a list as complete
post '/lists/:list_id/todos/complete_all' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been marked as completed.'
  redirect "/lists/#{@list_id}"
end



set :session_secret, SecureRandom.hex(32)
