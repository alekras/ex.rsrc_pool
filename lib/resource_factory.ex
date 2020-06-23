defmodule ResourceFactory do
  @moduledoc """
  The module defines a behaviour of resource factory.
  """
  @doc """
  Creates new resource.
  """
  @callback create(resource_metadata :: list()) :: {:ok, term()}
  @doc """
  Destroyes a resource.
  """
  @callback destroy(resource_metadata :: list(), resource :: pid()) :: :ok
  @doc """
  Validate resource: if resource is alive and valid then returns true, otherwise - false.
  """
  @callback validate(resource_metadata :: list(), resource :: pid()) :: boolean()
  @doc """
  Some action during activation of a resource before moving the resource from pool to client.
  """
  @callback activate(resource_metadata :: list(), resource :: pid()) :: :ok
  @doc """
  Some action during passivation of a resource after returning the resource from use to pool.
  """
  @callback passivate(resource_metadata :: list(), resource :: pid()) :: :ok
end

defmodule DefaultResourceFactory do
  @moduledoc """
  This module implements simple template of resource factory (ResourceFactory behaviour). It is for testing/debuging purpouse.
  """
  @behaviour ResourceFactory

  @impl true
  @doc """
  Create simple resource for testing. In real system new resource is created as process using resource metadata.
  """
  def create(_resource_metadata) do
    {:ok, make_ref()}
  end

  @impl true
  @doc """
  Do nothing with test resource. Real system will close and dispose the resource.
  """
  def destroy(_resource_metadata, _resource) do
    :ok
  end

  @impl true
  @doc """
  Test resource is always valid. Real system has to check health of given resource.
  """
  def validate(_resource_metadata, _resource) do
    true
  end

  @impl true
  @doc """
  Activate resource before starting to use.
  """
  def activate(_resource_metadata, _resource) do
    :ok
  end

  @impl true
  @doc """
  Passivate resource before going to idle.
  """
  def passivate(_resource_metadata, _resource) do
    :ok
  end

end
