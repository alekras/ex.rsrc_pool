defmodule NotFactory do

  def create(_resource_metadata) do
    TestResource.create()
  end

  def destroy(_resource_metadata, resource) do
    TestResource.stop(resource)
  end

  def validate(_resource_metadata, resource) do
    TestResource.valid?(resource)
  end

  def activate(_resource_metadata, resource) do
    TestResource.set_active(resource, true)
  end

  def passivate(_resource_metadata, resource) do
    TestResource.set_active(resource, false)
  end

end
