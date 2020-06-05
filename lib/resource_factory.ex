defmodule ResourceFactory do
  @callback create(resource_metadata :: term()) :: {:ok, term()}
  @callback destroy(resource_metadata :: term(), resource :: term()) :: :ok
  @callback validate(resource_metadata :: term(), resource :: term()) :: boolean()
  @callback activate(resource_metadata :: term(), resource :: term()) :: :ok
  @callback passivate(resource_metadata :: term(), resource :: term()) :: :ok
end

defmodule DefaultResourceFactory do
  @behaviour ResourceFactory

  @impl true
  def create(_resource_metadata) do
    {:ok, make_ref()}
  end

  @impl true
  def destroy(_resource_metadata, _resource) do
    :ok
  end

  @impl true
  def validate(_resource_metadata, _resource) do
    true
  end

  @impl true
  def activate(_resource_metadata, _resource) do
    :ok
  end

  @impl true
  def passivate(_resource_metadata, _resource) do
    :ok
  end

end