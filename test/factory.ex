defmodule Factory do
  @behaviour ResourceFactory

  @impl true
  def create(_resource_metadata) do
    TestResource.create()
  end

  @impl true
  def destroy(_resource_metadata, resource) do
    TestResource.stop(resource)
  end

  @impl true
  def validate(_resource_metadata, resource) do
    TestResource.valid?(resource)
  end

  @impl true
  def activate(_resource_metadata, resource) do
    TestResource.set_active(resource, true)
  end

  @impl true
  def passivate(_resource_metadata, resource) do
    TestResource.set_active(resource, false)
  end

end
